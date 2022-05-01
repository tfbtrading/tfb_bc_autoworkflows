codeunit 50704 "TFB Item Tracking API"
{
    var
        NotTempErr: Label '%1 shuld be temporary', Comment = '%1 = tablecaption';

    procedure GetItemTrackingFromWarehouseShipmentLine(WarehouseShipmentLine: Record "Warehouse Shipment Line"; var TempTrackingSpecification: Record "Tracking Specification"): Boolean
    var
        RedGetTracking: Codeunit "Red Get Tracking";
        RecordRef: RecordRef;
    begin
        if not TempTrackingSpecification.IsTemporary then
            Error(NotTempErr, TempTrackingSpecification.TableCaption);
        RecordRef.GetTable(WarehouseShipmentLine);
        RedGetTracking.GetTrackingSpecification(TempTrackingSpecification, RecordRef);
        exit(not TempTrackingSpecification.IsEmpty)
    end;

    procedure CreateItemTrackingFromWarehouseShipmentLine(WarehouseShipmentLine: Record "Warehouse Shipment Line"; var TempTrackingSpecification: Record "Tracking Specification")
    var
        Item: Record Item;
        PurchaseLine: Record "Purchase Line";
        SalesLine: Record "Sales Line";
        ServiceLine: Record "Service Line";
        TransferLine: Record "Transfer Line";
        SecondSourceQtyArray: array[3] of Decimal;
        Direction: Enum "Transfer Direction";
        AvailabilityDate: Date;
    begin
        if not TempTrackingSpecification.IsTemporary then
            Error(NotTempErr, TempTrackingSpecification.TableCaption);
        Item.Get(WarehouseShipmentLine."Item No.");
        Item.TestField("Item Tracking Code");

        SecondSourceQtyArray[1] := DATABASE::"Warehouse Shipment Line";
        SecondSourceQtyArray[2] := WarehouseShipmentLine."Qty. to Ship (Base)";
        SecondSourceQtyArray[3] := 0;

        case WarehouseShipmentLine."Source Type" of
            DATABASE::"Sales Line":
                if SalesLine.Get(WarehouseShipmentLine."Source Subtype", WarehouseShipmentLine."Source No.", WarehouseShipmentLine."Source Line No.") then
                    TempTrackingSpecification.InitFromSalesLine(SalesLine);
            DATABASE::"Service Line":
                if ServiceLine.Get(WarehouseShipmentLine."Source Subtype", WarehouseShipmentLine."Source No.", WarehouseShipmentLine."Source Line No.") then
                    TempTrackingSpecification.InitFromServLine(ServiceLine, false);
            DATABASE::"Purchase Line":
                if PurchaseLine.Get(WarehouseShipmentLine."Source Subtype", WarehouseShipmentLine."Source No.", WarehouseShipmentLine."Source Line No.") then
                    TempTrackingSpecification.InitFromPurchLine(PurchaseLine);
            DATABASE::"Transfer Line":
                begin
                    Direction := Direction::Outbound;
                    if TransferLine.Get(WarehouseShipmentLine."Source No.", WarehouseShipmentLine."Source Line No.") then
                        TempTrackingSpecification.InitFromTransLine(TransferLine, AvailabilityDate, Direction);
                end
        end;
    end;

    procedure RetrieveItemTrackingSummary(var TempTrackingSpecification: Record "Tracking Specification"; var TempEntrySummary: Record "Entry Summary"; var TempReservationEntry: Record "Reservation Entry")
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
        ReservationEntry: Record "Reservation Entry";
        TempxTrackingSpecification: Record "Tracking Specification" temporary;
        LastSummaryEntryNo: Integer;
    begin
        if not TempEntrySummary.IsTemporary then
            Error(NotTempErr, TempEntrySummary.TableCaption);
        TempxTrackingSpecification := TempTrackingSpecification;

        ReservationEntry.Reset();
        ReservationEntry.SetCurrentKey(
          "Item No.", "Variant Code", "Location Code", "Item Tracking", "Reservation Status", "Lot No.", "Serial No.");
        ReservationEntry.SetRange("Item No.", TempTrackingSpecification."Item No.");
        ReservationEntry.SetRange("Variant Code", TempTrackingSpecification."Variant Code");
        ReservationEntry.SetRange("Location Code", TempTrackingSpecification."Location Code");
        ReservationEntry.SetFilter("Item Tracking", '<>%1', ReservationEntry."Item Tracking"::None);
        if ReservationEntry.FindSet() then
            repeat
                TempReservationEntry := ReservationEntry;
                if CanIncludeReservationEntryToTrackingSpec(TempReservationEntry) then
                    TempReservationEntry.Insert();
            until ReservationEntry.Next() = 0;

        ItemLedgerEntry.Reset();
        ItemLedgerEntry.SetCurrentKey("Item No.", Open, "Variant Code", "Location Code", "Item Tracking",
          "Lot No.", "Serial No.");
        ItemLedgerEntry.SetRange("Item No.", TempTrackingSpecification."Item No.");
        ItemLedgerEntry.SetRange("Variant Code", TempTrackingSpecification."Variant Code");
        ItemLedgerEntry.SetRange(Open, true);
        ItemLedgerEntry.SetRange("Location Code", TempTrackingSpecification."Location Code");

        TransferItemLedgerToTempRec(ItemLedgerEntry, TempReservationEntry);

        TempTrackingSpecification := TempxTrackingSpecification;
        CopyToEntrySummary(TempTrackingSpecification, TempReservationEntry, TempEntrySummary, LastSummaryEntryNo);
        TempEntrySummary.Reset();
    end;

    local procedure CanIncludeReservationEntryToTrackingSpec(TempReservationEntry: Record "Reservation Entry" temporary): Boolean
    var
        SalesLine: Record "Sales Line";
    begin
        if (TempReservationEntry."Reservation Status" = TempReservationEntry."Reservation Status"::Prospect) and
           (TempReservationEntry."Source Type" = DATABASE::"Sales Line") and
           (TempReservationEntry."Source Subtype" = 2)
        then begin
            SalesLine.Get(TempReservationEntry."Source Subtype", TempReservationEntry."Source ID", TempReservationEntry."Source Ref. No.");
            if SalesLine."Shipment No." <> '' then
                exit(false);
        end;
        exit(true);
    end;

    local procedure TransferItemLedgerToTempRec(var ItemLedgerEntry: Record "Item Ledger Entry"; var TempReservationEntry: Record "Reservation Entry")
    begin
        if ItemLedgerEntry.FindSet() then
            repeat
                if ItemLedgerEntry.TrackingExists() and
                   not TempReservationEntry.Get(-ItemLedgerEntry."Entry No.", ItemLedgerEntry.Positive) and
                   not IsLotNumberInTemp(TempReservationEntry, ItemLedgerEntry."Lot No.")
                then begin
                    TempReservationEntry.Init();
                    TempReservationEntry."Entry No." := -ItemLedgerEntry."Entry No.";
                    TempReservationEntry."Reservation Status" := TempReservationEntry."Reservation Status"::Surplus;
                    TempReservationEntry.Positive := ItemLedgerEntry.Positive;
                    TempReservationEntry."Item No." := ItemLedgerEntry."Item No.";
                    TempReservationEntry."Variant Code" := ItemLedgerEntry."Variant Code";
                    TempReservationEntry."Location Code" := ItemLedgerEntry."Location Code";
                    TempReservationEntry."Quantity (Base)" := ItemLedgerEntry."Remaining Quantity";
                    TempReservationEntry."Source Type" := DATABASE::"Item Ledger Entry";
                    TempReservationEntry."Source Ref. No." := ItemLedgerEntry."Entry No.";
                    TempReservationEntry."Serial No." := ItemLedgerEntry."Serial No.";
                    TempReservationEntry."Lot No." := ItemLedgerEntry."Lot No.";

                    if TempReservationEntry.Positive then begin
                        TempReservationEntry."Warranty Date" := ItemLedgerEntry."Warranty Date";
                        TempReservationEntry."Expiration Date" := ItemLedgerEntry."Expiration Date";
                        TempReservationEntry."Expected Receipt Date" := 0D
                    end else
                        TempReservationEntry."Shipment Date" := DMY2Date(31, 12, 9999);

                    TempReservationEntry.Insert();
                end;
            until ItemLedgerEntry.Next() = 0;
    end;

    local procedure IsLotNumberInTemp(var TempReservationEntry: Record "Reservation Entry"; LotNo: Code[50]) Result: Boolean
    begin
        TempReservationEntry.Reset();
        TempReservationEntry.SetRange("Lot No.", LotNo);
        Result := not TempReservationEntry.IsEmpty();
        TempReservationEntry.Reset();
    end;

    local procedure CopyToEntrySummary(var TempTrackingSpecification: Record "Tracking Specification"; var TempReservationEntry: Record "Reservation Entry"; var TempEntrySummary: Record "Entry Summary"; var LastSummaryEntryNo: Integer)
    var
        LookupMode: Enum "Item Tracking Type";
    begin
        if TempReservationEntry.FindSet() then
            repeat
                CreateEntrySummary2(TempTrackingSpecification, LookupMode::"Serial No.", TempReservationEntry, TempEntrySummary, LastSummaryEntryNo);
                CreateEntrySummary2(TempTrackingSpecification, LookupMode::"Lot No.", TempReservationEntry, TempEntrySummary, LastSummaryEntryNo);
            until TempReservationEntry.Next() = 0;
    end;

    local procedure CreateEntrySummary2(TrackingSpecification: Record "Tracking Specification" temporary; LookupMode: Enum "Item Tracking Type"; TempReservationEntry: Record "Reservation Entry" temporary; var TempEntrySummary: Record "Entry Summary"; var LastSummaryEntryNo: Integer)
    var
        DoInsert: Boolean;
    begin
        TempEntrySummary.Reset();
        TempEntrySummary.SetCurrentKey("Lot No.", "Serial No.");

        // Set filters
        case LookupMode of
            LookupMode::"Serial No.":
                begin
                    if TempReservationEntry."Serial No." = '' then
                        exit;
                    // TempEntrySummary.SetTrackingFilterFromReservEntry(TempReservationEntry);
                    TempEntrySummary.SetRange("Serial No.", TempReservationEntry."Serial No.");
                    TempEntrySummary.SetRange("Lot No.", TempReservationEntry."Lot No.");
                end;
            LookupMode::"Lot No.":
                begin
                    // TempEntrySummary.SetTrackingFilterFromReservEntry(TempReservationEntry);
                    TempEntrySummary.SetRange("Serial No.", TempReservationEntry."Serial No.");
                    TempEntrySummary.SetRange("Lot No.", TempReservationEntry."Lot No.");
                    if TempReservationEntry."Serial No." <> '' then
                        TempEntrySummary.SetRange("Table ID", 0)
                    else
                        TempEntrySummary.SetFilter("Table ID", '<>%1', 0);
                end;
        end;

        if not TempEntrySummary.FindFirst() then begin
            TempEntrySummary.Init();
            LastSummaryEntryNo += 1;
            TempEntrySummary."Entry No." := LastSummaryEntryNo;

            if (LookupMode = LookupMode::"Lot No.") and (TempReservationEntry."Serial No." <> '') then
                TempEntrySummary."Table ID" := 0
            else
                TempEntrySummary."Table ID" := TempReservationEntry."Source Type";
            if LookupMode = LookupMode::"Serial No." then
                TempEntrySummary."Serial No." := TempReservationEntry."Serial No."
            else
                TempEntrySummary."Serial No." := '';
            TempEntrySummary."Lot No." := TempReservationEntry."Lot No.";
            // TempEntrySummary."Bin Active" := CurrBinCode <> '';
            // UpdateBinContent(TempEntrySummary);

            // If consumption/output fill in double entry value here:
            // TempEntrySummary."Double-entry Adjustment" :=
            //   MaxDoubleEntryAdjustQty(TrackingSpecification, TempEntrySummary);

            DoInsert := true;
        end;

        if TempReservationEntry.Positive then begin
            TempEntrySummary."Warranty Date" := TempReservationEntry."Warranty Date";
            TempEntrySummary."Expiration Date" := TempReservationEntry."Expiration Date";
            if TempReservationEntry."Entry No." < 0 then // The record represents an Item ledger entry
                TempEntrySummary."Total Quantity" += TempReservationEntry."Quantity (Base)";
            if TempReservationEntry."Reservation Status" = TempReservationEntry."Reservation Status"::Reservation then
                TempEntrySummary."Total Reserved Quantity" += TempReservationEntry."Quantity (Base)";
        end else begin
            TempEntrySummary."Total Requested Quantity" -= TempReservationEntry."Quantity (Base)";
            if TempReservationEntry.HasSamePointerWithSpec(TrackingSpecification) then begin
                if TempReservationEntry."Reservation Status" = TempReservationEntry."Reservation Status"::Reservation then
                    TempEntrySummary."Current Reserved Quantity" -= TempReservationEntry."Quantity (Base)";
                if TempReservationEntry."Entry No." > 0 then // The record represents a reservation entry
                    TempEntrySummary."Current Requested Quantity" -= TempReservationEntry."Quantity (Base)";
            end;
        end;

        TempEntrySummary.UpdateAvailable();
        if DoInsert then
            TempEntrySummary.Insert()
        else
            TempEntrySummary.Modify();
    end;
}