pageextension 50701 "TFB Auto Whse. Shipment" extends "Warehouse Shipment"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addlast(processing)
        {
            action(AutoItemTracking)
            {
                Caption = 'Auto Populate Lots';
                ToolTip = 'Automatically populate lots of items';
                ApplicationArea = All;
                Promoted = true;
                PromotedCategory = Process;
                Image = AutoReserve;

                trigger OnAction()
                var
                    Line: Record "Warehouse Shipment Line";
                    TempTrackingSpecification: Record "Tracking Specification" temporary;
                    TempEntrySummary: Record "Entry Summary" temporary;
                    TempReservationEntry: Record "Reservation Entry" temporary;
                    ItemTrackingAPI: Codeunit "TFB Item Tracking API";


                begin

                    Line.SetRange("No.", rec."No.");

                    If Line.Findset(false, false) then
                        repeat

                            if not ItemTrackingAPI.GetItemTrackingFromWarehouseShipmentLine(Line, TempTrackingSpecification) then
                                ItemTrackingAPI.CreateItemTrackingFromWarehouseShipmentLine(Line, TempTrackingSpecification);

                            ItemTrackingAPI.RetrieveItemTrackingSummary(TempTrackingSpecification, TempEntrySummary, TempReservationEntry);

                            If not TempEntrySummary.IsEmpty() then begin
                                TempEntrySummary.FindSet(false, false);
                                repeat
                                    TempTrackingSpecification."Lot No." := TempEntrySummary."Lot No.";
                                    //TODO HANDLE MULTIPLE LOTS
                                    If Line."Qty. to Ship (Base)" <= TempEntrySummary."Total Available Quantity" then begin
                                        TempTrackingSpecification."Quantity (Base)" := TempEntrySummary."Total Quantity";
                                        //TempTrackingSpecification.Modify();
                                        TempTrackingSpecification.InsertSpecification();
                                    end;

                                until TempEntrySummary.Next() = 0;
                            end
                        until Line.Next() = 0;

                end;

            }
        }
    }
}
