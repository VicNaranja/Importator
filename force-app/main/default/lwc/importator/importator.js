import { track,wire,api  } from 'lwc';
import { LightningElement } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import papaparse from '@salesforce/resourceUrl/papaparse';
import xlsx from '@salesforce/resourceUrl/xlsx';
import getObjectsSalesforce from '@salesforce/apex/ImportTatorController.getObjectsSalesforce';
import getFieldsSalesforce from '@salesforce/apex/ImportTatorController.getFieldsSalesforce';
import importData from '@salesforce/apex/ImportTatorController.importData';

export default class Importator extends LightningElement {

    /*************** Variables TAB Origen ****************/
    config=[];//Variable de configuracion de parseo PAPAPARSE
    @track objectFile = []; //Objeto con el csv parseado
    @track objectFilePreview = []; //Objeto con el preview de las primeras 20 lineas
    @track fileName = ''; //Nombre del fichero seleccionado
    @track fileRead = false; //true cuando se parsea el fichero
    @track numerolineasLimpiadas = 0;
    @track lineasLimpiadas = false;

    /*************** Variables TAB Destino ****************/
    @track listaOpcionesImport=[]; //Insertar, actualizar o borrar dependiendo de los permisos del objeto
    @wire(getObjectsSalesforce) listaObjetos; //Lista de objetos distino; OJO el resultado esta dentro de la variable data
    

    /*************** Variables TAB Mapeo ****************/    
    @track listaCampos = [];
    definicionImport = {
        columnas : [],
        objetoDestino : '',
        accion : '',
        mapeo : null,
        mapeoLookups : null,
        test : false
    }; //variable con la configuracion de mapeo
    mapaLookups = new Map();
    
    /*************** Variables TAB Resultado ****************/
    @track errorResultados = false;
    @track textoErrorResultados = '';
    @track inicioImport = false; //true cuando se inicia el proceso de importacion

    /************** Modal Lookup ********************/
    @track showLookupModal; //Indica si mostramos el componenete de lookups
    @track columnLookup; //Indica la columna a la que queremos hacer un lookup
    fieldLookup;
    @track valueLookup; //Indica la configuracion del propio lookup
    
    /************* FUNCIONES  *************************** */

    //funcion de inicio
    async connectedCallback()
    {
        //Carga de JS externos
        await loadScript(this, papaparse + '/papaparse.min.js');
        await loadScript(this, xlsx + '/xlsx.full.min.js');
         
        //construimos configuracion de parseo CSV PapaParse
        this.config = this.buildConfig();                
    }

    //Detecta un cambio en el input fichero
    onChangeFile()
    {        
        if (this.template.querySelector("input[type=file]").files[0])
        {
            var fileName = this.template.querySelector("input[type=file]").files[0].name;
            if (fileName.endsWith('.csv'))
                this.parseCSV();
            else if (fileName.endsWith('.xlsx'))            
                this.parseExcel();
        } 
        //Generamos los datos para los mapeos
        this.generateMapping();
    }
    //Carga el fichero 
    loadData(data)
    {
        this.inicioImport = false;//Reseteamos resultados
        //Fichero CSV parseado            
        console.log("loadData", data);    
        //Muestro el contenido por pantalla
        this.objectFile = data;                                       
        
        //Genero un nuevo array con las columnas para que no les afecte futuras modificaciones
        this.definicionImport.columnas = Array.from(data.slice(0,1)[0]);
        console.log('columns', this.definicionImport.columnas);                

        //Limpio lineas vacias
        this.numerolineasLimpiadas = 0;
        this.lineasLimpiadas = false;
        for(var i = 0 ; i<data.length;i++)
        {
            console.log('data[i].length::' + data[i].length);
            console.log('this.definicionImport.columnas.length::' + this.definicionImport.columnas.length);
            if (data[i].length < this.definicionImport.columnas.length)
            {
                console.log('splice ' , data[i])
                data.splice(i,1);
                i--;
                this.numerolineasLimpiadas++;
                this.lineasLimpiadas = true;
            }
            else if (data[i].length == 1 && data[i] == '')
            {
                console.log('splice ' , data[i])
                data.splice(i,1);
                i--;
                this.numerolineasLimpiadas++;
                this.lineasLimpiadas = true;
            }
        }
        
        //Genero el preview en otro array para que no afecte las futuras modificaciones
        this.objectFilePreview = JSON.parse(JSON.stringify(data.slice(0,21)));//Clonamos array                

        this.fileRead = true;
    }

    //Parsea el Excel utilizando la libreria xlsx
    parseExcel()
    {        
        console.log("parseEXCEL");
        that = this;
    
        this.fileName = this.template.querySelector("input[type=file]").files[0].name;
        var f = this.template.querySelector("input[type=file]").files[0]
        var reader = new FileReader();
        reader.onload = function(e) {
            var data = new Uint8Array(e.target.result);
            var workbook = XLSX.read(data, {type: 'array'});

            var result = {};
            workbook.SheetNames.forEach(function(sheetName) {
                var roa = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], {header:1,defval:""});
                result = roa;
            });
            that.loadData(result);
        };

        reader.readAsArrayBuffer(f);
        
    }

    //funcion para parsear el fichero seleccionado
    parseCSV()
    {
        console.log('parseCSV');
        //Guardamos variable global
        that = this;

        //Rellenamos input text
        this.fileName = this.template.querySelector("input[type=file]").files[0].name;

        //Papaparse party
        Papa.parse( this.template.querySelector("input[type=file]").files[0], {
            config: this.config,
            before: function(file)
            {
                console.log("Parsing file...", file);
            },
            error: function(err, file)
            {
                console.log("ERROR:", err, file);                
            },
            complete: function(result)
            {    
                that.loadData(result.data);                       
            }
        });


    } 

    //Cuando el usuario pulsa el boton de recargar fichero
    onReload()
    {
        this.onChangeFile();        
    }

    //funcion que genera el objeto de configuracion de PapaParse
    buildConfig()
    {
        return {
            delimiter: "",	// auto-detect
            newline: "",	// auto-detect
            quoteChar: '"',
            escapeChar: '"',
            header: true,
            transformHeader: undefined,
            dynamicTyping: false,
            preview: 0,
            encoding: "UTF-8",
            worker: false,
            comments: false,
            step: undefined,
            complete: undefined,
            error: undefined,
            download: false,
            downloadRequestHeaders: undefined,
            downloadRequestBody: undefined,
            skipEmptyLines: false,
            chunk: undefined,
            fastMode: undefined,
            beforeFirstChunk: undefined,
            withCredentials: undefined,
            transform: undefined,
            delimitersToGuess: [',', '\t', '|', ';', Papa.RECORD_SEP, Papa.UNIT_SEP]
        };
    }

    //Detecta que el usuario elige un objeto nuevo para realizar la carga
    onObjectChange()
    {
        //Recuperamos el valor seleccionado
        var select = this.template.querySelector("select.selectObject");        
        var objetoSeleccionadoTexto = select.options[select.selectedIndex].value;
        
        //Actualizamos el objeto destino en la definicion del import
        this.definicionImport.objetoDestino = objetoSeleccionadoTexto;
        this.definicionImport.accion = '';

        //Inicializa el select de accion para que el usuario vuelva a elegir accion
        this.template.querySelector("select.selectOption").options[0].selected = 'selected'

        //Recuperamos el objeto del array
        var objectoSeleccionado = this.listaObjetos.data.find(x => x.name == objetoSeleccionadoTexto);        
        console.log('onObjectChange:' , select.options[select.selectedIndex].value);
        
        //Inicializamos las opciones disponibles
        this.listaOpcionesImport = [];

        if (objectoSeleccionado)
        {            
            //Rellenamos las acciones segun los permisos del objeto            
            if (objectoSeleccionado.isCreatable)
            {
                this.listaOpcionesImport.push('Insertar');
            }
            if (objectoSeleccionado.isUpdateable)
            {
                this.listaOpcionesImport.push('Actualizar');
            }
            if (objectoSeleccionado.isDeletable)
            {
                this.listaOpcionesImport.push('Eliminar');
            }

            //Generamos los datos para los mapeos
            this.generateMapping();
        } 
        
    }

    //Detecta un cambio en la accion a realizar
    onActionChange()
    {
        var select = this.template.querySelector("select.selectOption");   
        console.log('onActionChange:' + select.options[select.selectedIndex].value);

        if (select.options[select.selectedIndex].value == 'Insertar' ||
            select.options[select.selectedIndex].value == 'Actualizar' ||
            select.options[select.selectedIndex].value == 'Eliminar')
        {     
            this.definicionImport.accion = select.options[select.selectedIndex].value;        
        }
        else
        {
            this.definicionImport.accion = '';
        }

        //Generamos los datos para los mapeos
        this.generateMapping();
    }

    //Cuando el usuario selecciona un mapeo ponemos el fondo de otro color para que quede claro
    onMappingChange(event)
    {
        var select = event.target;
        if (select.selectedIndex > 0)
            this.selectedBackground(select,true);
        else
            this.selectedBackground(select,false);
        
    }

    //Cambia el fondo del desplegable a otro color
    selectedBackground(select, selected)
    {
        if (selected && !select.classList.contains('selectSelected'))
            select.classList.add('selectSelected');        
        else if (!selected && select.classList.contains('selectSelected'))
            select.classList.remove('selectSelected');        
    }

    //Recorre los campos de Salesforce buscando matches con los nombres de las columnas
    onAutomatch()
    {
        //Recupero selects de mapeo
        var selects = this.template.querySelectorAll("select.selectMapping");

        for(var i=0; i<selects.length; i++ )
        {
            var select = selects[i];
            
            for (var o=0; o<select.options.length; o++)
            {
                if (select.options[o].value == select.options[o].text)
                {
                    select.selectedIndex = o;
                    this.selectedBackground(select,true);
                    break;
                }
            }

        }
    }

    //Descarga los campos del objeto de Salesforce para realizar los mapeos
    //Solo descarga si existe campo y accion seleccionados de la pantalla destino
    async generateMapping()
    {
        console.log('getFields');
        if (this.definicionImport.objetoDestino && this.definicionImport.accion )
        {
            this.listaCampos = await getFieldsSalesforce({myObject: this.definicionImport.objetoDestino , 
                                                          action : this.definicionImport.accion,
                                                          withSharing : true });

            //Limpio la seleccion de los mapeos por si estuvieran seleccionados
            var selects = this.template.querySelectorAll("select.selectMapping");
            for(var i=0; i<selects.length; i++ )
            {
                selects[i].selectedIndex = 0;    
                this.selectedBackground(selects[i],false);            
            }
         
        }   
        else
        {
            this.listaCampos = [];
        }       
 
    }

    //Se ejecuta cuando el usuario pulsa el boton de test inicio
    onInicioTestImport()
    {
        this.definicionImport.test = true; //La importacion no se guarda en salesforce. Se usa para realizar un test.
        this.doImport();
    }

    onInicioImport()
    {
        this.definicionImport.test = false; //La importacion no se guarda en salesforce. Se usa para realizar un test.
        this.doImport();
    }
    //Se ejecuta cuando el usuario pulsa el boton de inicio
    async doImport()
    {
        //Iniciamos variable de errores;
        this.errorResultados = false;

        //Validacion del chunk size
        var inputChunk = this.template.querySelectorAll(".inputChunk input");
        var chunkSize = 100;
        if (inputChunk.value && chunkSize <= 200)
            chunkSize = inputChunk.value;

        //Valido si se ha leido el fichero
        if (!this.fileRead)
        {
            this.errorResultados = true;
            this.textoErrorResultados = 'Seleccione un origen antes de empezar el proceso';
            return;
        }
        
        //Valido si tenemos objeto destino y accion
        if (!this.definicionImport.objetoDestino && !this.definicionImport.accion)
        {
            this.errorResultados = true;
            this.textoErrorResultados = 'Seleccione un objeto destino antes de empezar el proceso';
            return;
        }

        //inicio variables mapeo       
        this.definicionImport.mapeo = {};        
        //Componemos el mapa con los mapeos recorriendo todos los select
        var selects = this.template.querySelectorAll("select.selectMapping");
        //Para cada select, si esta relleno guardamos mapeo
        var existeMapeo = false;
        for(var i=0; i<selects.length; i++ )
        {
            var select = selects[i];
            if (select.selectedIndex > 0)
            {
                this.definicionImport.mapeo[select.options[select.selectedIndex].text] = select.options[select.selectedIndex].value;
                existeMapeo = true;                
            }
        }
        if (!existeMapeo)
        {
            this.errorResultados = true;
            this.textoErrorResultados = 'Seleccione al menos un mapeo antes de empezar el proceso';
            return;
        }

        //Inicio variable lookup        
        this.definicionImport.mapeoLookups = {};
        //Convierto el mapa en objetos para poder convertirlo en string
        this.mapaLookups.forEach((value, key) => {
            this.definicionImport.mapeoLookups[key] = JSON.parse(JSON.stringify(value));
        });
        
        //Iniciamos proceso
        this.inicioImport = true;

        //Modificamos fichero para añadir columnas de estado
        if (this.objectFile[0].length == this.definicionImport.columnas.length)
        {
            this.objectFile[0].push('isSuccess');
            this.objectFile[0].push('id');
            this.objectFile[0].push('error');
        }
        else
        {
            //Es un reintento. Limpio resultados anteriores
            for (var i = 1; i < this.objectFile.length; i++)
            {
                this.objectFile[i].pop();
                this.objectFile[i].pop();
                this.objectFile[i].pop();
            }
        }

        //Procesamos fichero por lotes chunksize
        for (var i = 1; i < this.objectFile.length; i += chunkSize)
        {
            console.log('importData');
            var resultado =  await importData({objects: JSON.stringify(this.objectFile.slice(i, i + chunkSize)), 
                                               definicion : JSON.stringify(this.definicionImport)})

            
            /********* acoplo los resultados al array del fichero para visualizarlo en el pantalla********/
            
            //Variable para recorrer los resultados del WS
            var indiceResultado = 0;

            //Variable con el indice maximo del fichero por chunk
            var numRows = i + chunkSize;
            if (numRows > this.objectFile.length)
                numRows = this.objectFile.length;

            //Para cada fila del fichero le acoplamos el resultado del WS
            for(var k = i ; k < numRows  ; k++)
            {               
                //k es el indice de la linea procesada
                console.log('para cada resultado');
                if (resultado[indiceResultado].isSuccess)
                    this.objectFile[k].push('icon:true');
                else
                    this.objectFile[k].push('icon:false');

                if (resultado[indiceResultado].id)
                    this.objectFile[k].push(resultado[indiceResultado].id);
                else
                    this.objectFile[k].push('');

                if (resultado[indiceResultado].error)
                    this.objectFile[k].push(resultado[indiceResultado].error);
                else
                    this.objectFile[k].push('');
               
                indiceResultado++;
            }
        }
        
    }
   
    //El usuario pulsa el boton de nuevo lookup
    openLookup(event)
    {
        //Solo abrimos si existe campo seleccionado
        var campo  = event.target.getAttribute('data-column');
        console.log(event.target.getAttribute('data-column'));  

        //Recupero el select del campo mapeados
        var select = this.template.querySelectorAll("select.selectMapping[data-column=" + campo + "]" )[0];

        if (select && select.selectedIndex > 0)
        {            
            //Si hay mapeo dejo intoducir lookup
            this.showLookupModal = true; 
            this.columnLookup = select.options[select.selectedIndex].text;     
            this.fieldLookup = select.options[select.selectedIndex].value;    
            this.valueLookup = this.mapaLookups.get(this.columnLookup);            
        }   
        else
        {
            alert('Para crear un lookup primero añada un mapeo con el campo de Salesfroce');
        }  
                
    }

    cancelLookup()
    {
        this.showLookupModal = false; 
    }
      
    saveLookup(event)
    {
        if (event.detail.objetoDestino == 'Seleccione el objeto destino')
        {
            //Se borra el lookup
            this.mapaLookups.delete(this.columnLookup);
        }
        else
        {
            //Se actualiza el lookup
            this.mapaLookups.set(this.columnLookup, event.detail);
            
            console.log('saveLookup::' , this.mapaLookups);
            
            var divLookup = this.template.querySelectorAll('[data-id='+ this.fieldLookup +']')[0];
            divLookup.classList.add('rellenado');
        }
        this.showLookupModal = false; 
    }

  
       

}