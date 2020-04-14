import { LightningElement } from 'lwc';
import { track,api } from 'lwc';

export default class ImportatorColumnValue extends LightningElement {

    @track img = false;
    @track datos = false;

    @track ok = false;
    @track ko = false;
    
    @track columnData;

    @api
    get columna() {
        return this.columnData
    }

    set columna(value) 
    {        
        this.columnData = value;
        if (value == 'icon:true')
        {
            this.img = true;
            this.ok = true;
        }
        else if (value == 'icon:false')
        {
            this.img = true;
            this.ko = true;
        }
        else
        {
            this.datos = true;
        }
    }

}