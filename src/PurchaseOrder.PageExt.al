pageextension 50702 "Auto Purchase Order Ext" extends "Purchase Order"
{
    layout
    {
        addlast(General)
        {
            field("TFB Send Hold"; rec."TFB Send Hold")
            {
                Caption = 'Send Hold';
                ToolTip = 'Stops any automated email from being sent';
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

   
}