tableextension 50700 "Auto TFB Purchase Header Ext" extends "Purchase Header"
{
    fields
    {
        field(50700; "TFB Send Hold"; Boolean)
        {
            DataClassification = CustomerContent;
        }
    }


}