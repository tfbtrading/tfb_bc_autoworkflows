codeunit 50700 "TFB Send Invoices in Batch"
{
    trigger OnRun()

    var


    begin
        SendReadyInvoices();
    end;

    /// <summary> 
    /// Check for and send any sales invoices that are ready
    /// </summary>
    procedure SendReadyInvoices()

    var
        SalesInvoiceHeader: Record "Sales Invoice Header";


    begin

        SalesInvoiceHeader.SetRange("No. Printed", 0);
        SalesInvoiceHeader.SetFilter("Remaining Amount", '>0');
        SalesInvoiceHeader.SetFilter("Document Date", '>=%1', today());

        If not SalesInvoiceHeader.IsEmpty() then
            SalesInvoiceHeader.EmailRecords(false);


    end;

}