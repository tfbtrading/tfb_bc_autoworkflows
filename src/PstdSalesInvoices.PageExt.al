pageextension 50700 "TFB Pstd Sales Invoices" extends "Posted Sales Invoices"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addafter(SendCustom)
        {
            action(ActionName)
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Send Ready Invoices';
                Ellipsis = true;
                Image = SendToMultiple;
                Promoted = true;
                PromotedCategory = Category7;
                PromotedIsBig = true;
                PromotedOnly = true;
                ToolTip = 'Prepare to send the document according to the customer''s sending profile, such as attached to an email. The Send document to window opens where you can confirm or select a sending profile.';

                trigger OnAction()
                var
                    CU: CodeUnit "TFB Send Invoices in Batch";
                begin
                    CU.SendReadyInvoices();
                end;
            }
        }
    }


}