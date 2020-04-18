import { LightningElement } from 'lwc';
import { track,wire,api  } from 'lwc';

import getFieldsSalesforce from '@salesforce/apex/ImportTatorController.getFieldsSalesforce';
import getObjectsSalesforce from '@salesforce/apex/ImportTatorController.getObjectsSalesforce';

export default class ImportatorLookup extends LightningElement 
{

    @track columnaLookup; //columna del fichero asociada al lookup
    @track valueLookup; //valor del lookup

    @track errorLookup;//mensjae de error del formulario
    
    @wire(getObjectsSalesforce) listaObjetos; //lista completa de objetos de SF
    @track listaCampos; //lista de campos dependiende del objeto seleccionado

    @api
    get columnaLookup() {
        return this.columnaLookup;
    }

    set columnaLookup(value) {
       this.columnaLookup = value;
    }

    @api
    get valueLookup() {
        return this.valueLookup;
    }

    set valueLookup(value) {
       this.valueLookup = value;
    }


    //init
    async renderedCallback()
    {
        console.log('load lookup columna:',this.columnaLookup );
        console.log('load lookup value:',this.valueLookup );

        //Si tengo valores para la columna actual relleno los desplegables con dichos valores
        if (this.valueLookup)
        {
            var selectObjetoDestino = this.template.querySelectorAll("select.selectObjectLookup")[0];

            for (var o=0; o<selectObjetoDestino.options.length; o++)
            {
                if (selectObjetoDestino.options[o].value == this.valueLookup.objetoDestino)
                {
                    selectObjetoDestino.selectedIndex = o;       
                    
                    this.listaCampos = await getFieldsSalesforce({myObject: this.valueLookup.objetoDestino , 
                                                                action : '',
                                                                withSharing : false });
                    //Marcamos el resto de campos
                    var selectCampoDestino = this.template.querySelectorAll("select.selectFieldLookup")[0];                    
                    for (var o=0; o<selectCampoDestino.options.length; o++)
                    {
                        if (selectCampoDestino.options[o].value == this.valueLookup.campoDestino)
                        {
                            selectCampoDestino.selectedIndex = o;       
                        }
                    }

                    var selectCampoRecuperar = this.template.querySelectorAll("select.selectGetFieldLookup")[0];                    
                    for (var o=0; o<selectCampoRecuperar.options.length; o++)
                    {
                        if (selectCampoRecuperar.options[o].value == this.valueLookup.campoResultado)
                        {
                            selectCampoRecuperar.selectedIndex = o;       
                        }
                    }

                    break;
                }
            }                               
        }
    }

    //Cuando se modifica el desplegable de los objetos recargamos los campos a seleccionar
    async onChangeObject()
    {
        var selectObjetoDestino = this.template.querySelectorAll("select.selectObjectLookup")[0];
        var objetoDestino =  selectObjetoDestino.options[selectObjetoDestino.selectedIndex].value;

        this.columnaLookup = selectObjetoDestino;
        this.valueLookup = null; //reinicializo valores

        
        this.listaCampos = await getFieldsSalesforce({myObject: objetoDestino , 
                                         action : '',
                                         withSharing : false });

        //Recuperamos campo destino
        var selectCampoDestino = this.template.querySelectorAll("select.selectFieldLookup")[0];
        selectCampoDestino.selectedIndex = 0;
        //Recuperamos campo a recuperar
        var selectCampoRecuperar = this.template.querySelectorAll("select.selectGetFieldLookup")[0];
        selectCampoRecuperar.selectedIndex = 0;

    }

       

    //El usuario pulsa el boton de guardar lookup
    saveLookup()
    {        
        //Recuperamos objeto destino
        var selectObjetoDestino = this.template.querySelectorAll("select.selectObjectLookup")[0];
        var objetoDestino =  selectObjetoDestino.options[selectObjetoDestino.selectedIndex].value;
        //Recuperamos campo destino
        var selectCampoDestino = this.template.querySelectorAll("select.selectFieldLookup")[0];
        var campoDestino =  selectCampoDestino.options[selectCampoDestino.selectedIndex].value;
        //Recuperamos campo a recuperar
        var selectCampoRecuperar = this.template.querySelectorAll("select.selectGetFieldLookup")[0];
        var campoResultado =  selectCampoRecuperar.options[selectCampoRecuperar.selectedIndex].value;
       
       if (
          (selectObjetoDestino.selectedIndex > 0 &&
           selectCampoDestino.selectedIndex > 0 &&
           selectCampoRecuperar.selectedIndex > 0
          ) ||
          (selectObjetoDestino.selectedIndex == 0 &&
            selectCampoDestino.selectedIndex == 0 &&
            selectCampoRecuperar.selectedIndex == 0
           )
           )
        {
            //Lanzamos evento con los datos seleccionados
            const saveLookupEvent = new CustomEvent('save', { detail: {
                objetoDestino: objetoDestino,
                campoDestino: campoDestino,
                campoResultado: campoResultado
            } });
            this.dispatchEvent(saveLookupEvent);
        }
        else
        {
            this.errorLookup = 'Rellene todos los campos para guardar un lookup o deje todos vacios para borrarlo.'
        }

    }

    //El usuario sale de la ventana lookup
    cancelLookup()
    {
        //Lanzo evento de cierre
        const cancelLookupEvent = new CustomEvent('cancel',{});
        this.dispatchEvent(cancelLookupEvent);     
    }



}