/*
* Clase controladora del componenete importTATOR
*/
global with sharing class ImportTatorController
{
    
    // Recupera todos los objetos de Salesforce 
    @AuraEnabled (cacheable=true)
    public static List<ImportObject> getObjectsSalesforce()
    {
        List<ImportObject> resultado = new List<ImportObject>();

        Map<string, SObjectType> objs = schema.getGlobalDescribe();
        for(string key: objs.keySet())
        {
            DescribeSObjectResult describe = objs.get(key).getDescribe();
            
            if (describe.isUpdateable() || describe.isCreateable() || describe.isDeletable())
            {
                ImportObject io = new ImportObject();
                io.name = objs.get(key).getDescribe().getName();
                io.isCreatable = describe.isCreateable();
                io.isUpdateable = describe.isUpdateable();
                io.isDeletable = describe.isDeletable();
                resultado.add(io);
            }            
        }
        return resultado;
    }

    // Recupera todos los campos de Salesforce a partir de un objeto y accion proporcionados
    // Solo recuperara los campos si son accesibles para la accion seleccionada
    @AuraEnabled (cacheable=true)
    public static List<ImportFields> getFieldsSalesforce(String myObject, String action, Boolean withSharing)
    {
        system.debug('getFieldsSalesforce::' + myObject + ' ' + action);
        if (String.isBlank(myObject))
            return null;

        List<ImportFields> resultado = new List<ImportFields>();

        Map<string, SObjectType> objs = schema.getGlobalDescribe();
        for(string key: objs.keySet())
        {
            if (key == myObject)
            {
                system.debug('Objeto encontrado::' + myObject);
                DescribeSObjectResult describe = objs.get(key).getDescribe();                
                Map<String, Schema.SObjectField> fieldMap =  describe.fields.getMap();

                for(String keyField : fieldMap.keySet())
                {
                    DescribeFieldResult fieldDescribe = fieldMap.get(keyField).getDescribe();
                    system.debug('fieldDescribe::' + fieldDescribe.getName());

                    if (fieldDescribe.isAccessible())
                    {
                        if (withSharing)
                        {
                            system.debug('withSharing');
                            if (action == 'Insertar' &&  fieldDescribe.isCreateable() ||
                                (action == 'Actualizar' && (fieldDescribe.isUpdateable() || fieldDescribe.getName() == 'Id')  ) ||
                                action == 'Eliminar' && fieldDescribe.getName() == 'Id')
                            {
                                ImportFields io = new ImportFields();
                                io.name = fieldDescribe.getName();                           
                                io.label = fieldDescribe.getLabel();   
                                resultado.add(io);
                            }
                        }
                        else 
                        {
                            //No tiene en cuenta la accion. Se utiliza para recuperar campos de lookup
                            ImportFields io = new ImportFields();
                            io.name = fieldDescribe.getName();                           
                            io.label = fieldDescribe.getLabel();   
                            resultado.add(io);
                        }
                    }                    
                }                                
            }
        }
        system.debug('getFieldsSalesforce::resultado::' + resultado);
        resultado.sort();
        return resultado;
    }


    //Metodo principal donde se produce la importacion de datos
    @AuraEnabled
    public static List<ImportResult> importData(String objects, String definicion)
    {
        system.debug('importData::objects::' + objects);
        system.debug('importData::definicion::' + definicion);
        
        //Parseamos objetos
        List<Object> listaObjetos = (List<Object>)JSON.deserializeUntyped(objects);


        //Genermoas mapa final de resultados a devolver
        List<ImportResult> resultado = generarListaResultados(listaObjetos.size());

        try 
        {
            
            //Parseamos configuracion
            ImportConfig config = (ImportConfig)JSON.deserialize(definicion, ImportConfig.class);
            
            //Recuperamos definicion de obeto de salesforce a importar
            Schema.SObjectType objetoSF = Schema.getGlobalDescribe().get(config.objetoDestino);
            //Recuperamos definicion de campos del objeto
            Map<String, Schema.SObjectField> fieldsMap = objetoSF.getDescribe().fields.getMap();

            //Creamos objeto a insertar/actualizar
            List<SObject> listaObjetosImportar = new List<SObject>();

            //Mediante este mapa anotaremos en que posicion se tiene que devolver el resultado obtenido por la insercion/actualizacion en Salesforce
            //Generamente sera uno a uno, salvo en los casos de fallos de lookups
            Map<Integer,Integer> mapaCorrelacionesResultados = new Map<Integer,Integer>();

            /************************************************************************** GEENRAMOS LOOKUPS ***************************************************** */

            //Genero mapa con los lookps
            Map<String,Map<String,String>> mapaLookups = generarMapaLookups(listaObjetos, config);

            /************************************************************************** PARSEAMOS FICHERO FILA A FILA ************************************************* */
            //Procesamos fichero
            Integer i = 0;//fila
            Integer k = 0;//columna       
            for (Object l : listaObjetos) 
            {
                //PAra cada fila
                try 
                {
                    system.debug('Proceso linea ' + i + ' ' + l);
                    //Creo el objeto correspondiente
                    sObject nuevoObjeto = objetoSF.newSObject();
                    
                    k=0;//Inicializo el contador de columnas
                    
                    for (Object c : (List<Object>)l) 
                    {
                        //Para cada columna
                    
                        system.debug('Proceso columna ' + k + ' ' + c);
                        /*********Añado dicho valor al objeto de salesfroce a importar*******/
                        String textoColumna = quitaComillas((String)c);
                        //Columna actual a procesar
                        String columnaActual = quitaComillas(config.columnas[k]);
                        //Nombre api del campo de Salesforce 
                        String campoSalesforce = quitaComillas(config.mapeo.get(columnaActual));
                        //Descripcion de dicho campo (Se podria sacar fuera del for para ahorrar tiempo)
                        if (fieldsMap.containsKey(campoSalesforce))
                        {
                            /******************************** PROCESAMIENTO LOOKUP ***********************/
                            textoColumna = obtenerLookup(columnaActual, textoColumna, mapaLookups, resultado[i]);
                                                
                            /*************************** PROCESAMIENTO SEGUN EL TIPO DE CAMPO ***************/

                            //Si la columna esta en el mapeo la procesamos
                            Schema.DescribeFieldResult descripcionCampoSF = fieldsMap.get(campoSalesforce).getDescribe();
                            //Nuevo objeto que representa el campo a insertar
                            Object newField;

                            try 
                            {
                                /********** Convierto el valor segun el tipo de campo *************************/
                                if (descripcionCampoSF.getSoapType() == Schema.SOAPType.DateTime)
                                {
                                    newField = Datetime.valueOf((String)textoColumna);
                                }
                                else if (descripcionCampoSF.getSoapType() == Schema.SOAPType.Boolean)
                                {
                                    newField = Boolean.valueOf((String)textoColumna);
                                }
                                else if (descripcionCampoSF.getSoapType() == Schema.SOAPType.Date)
                                {
                                    newField = Date.valueOf((String)textoColumna);
                                }
                                else if (descripcionCampoSF.getSoapType() == Schema.SOAPType.Time)
                                {                    
                                    String[] strTimeSplit = ((String)textoColumna).split(':');
                                    newField = Time.newInstance( Integer.valueOf(strTimeSplit[0]) //hour
                                                                ,Integer.valueOf(strTimeSplit[1]) //min
                                                                ,0                                //sec
                                                                ,0);  
                                }
                                else if (descripcionCampoSF.getSoapType() == Schema.SOAPType.Double)
                                {
                                    newField = Double.valueOf((String)textoColumna);
                                }
                                else if (descripcionCampoSF.getSoapType() == Schema.SOAPType.Integer)
                                {
                                    newField = Integer.valueOf((String)textoColumna);
                                }
                                else 
                                {                  
                                    //Texto puro y duro                          
                                    newField = textoColumna; 
                                }      
                            }
                            catch (Exception ex)
                            {
                                //Pruebo a meter tal cual lo que viene y que SF me de el error                    
                                newField = textoColumna; 
                            }                  

                            // Establezco el valor del campo con el formato correcto al objeto
                            nuevoObjeto.put(
                                    campoSalesforce,
                                    newField
                            ); 
                        }
                        k++;//Aumentamos contador de columnas
                    }

                    //Si el procesamiento de la fila es correcto, añado el objeto a la lista de objetos a importar
                    listaObjetosImportar.add(nuevoObjeto);
                    //anoto la correlacion de resultados. De esta forma sabemos en que posicion de la lista de resultados tendremos que guardar el resultado de SF 
                    //Es posible que haya lineas erroneas y por lo tanto no entren como objetos a importar. Por ejemplo en el caso de los lookups.
                    mapaCorrelacionesResultados.put(listaObjetosImportar.size() - 1, i);//NumFilaObjetoSF -> Num Fila.                     
                } 
                catch (LookupException ex) 
                {                    
                    //Dejo seguir a la siguiente fila
                }                   
               
                system.debug('mapaCorrelacionesResultados::' + mapaCorrelacionesResultados);
                i++;
            }

            /************************************************************************** IMPORTACION EN SF ***************************************************** */
            Savepoint sp = Database.setSavepoint();
            
            try
            {
                //Insertamos o actualizamos segun operacion
                if (config.accion == 'Insertar')
                {
                    system.debug('Realizamos insercion');
                    completarResultados(Database.insert(listaObjetosImportar, false),resultado,mapaCorrelacionesResultados);           
                }
                else if (config.accion == 'Actualizar')
                {            
                    completarResultados(Database.update(listaObjetosImportar, false),resultado,mapaCorrelacionesResultados);  
                }
                else if (config.accion == 'Eliminar')
                {            
                    completarResultados(Database.delete(listaObjetosImportar, false),resultado,mapaCorrelacionesResultados);  
                }
                else 
                {
                    throw new ImportException('accion no esperada');
                }
            } 
            catch (Exception ex)
            {                
                system.debug('Exception::' + ex.getLineNumber());                
                //Devolvemos el error para cada registro teniendo en cuenta la correlacion por si ha habido errores previos           
                for (Integer indiceError=0; indiceError<listaObjetosImportar.size(); indiceError++) 
                {                                    
                    resultado[mapaCorrelacionesResultados.get(indiceError)].isSuccess = false;
                    resultado[mapaCorrelacionesResultados.get(indiceError)].id = null;
                    resultado[mapaCorrelacionesResultados.get(indiceError)].error = ex.getMessage();                    
                } 
            }       

            //Si es un test hacemos rollback
            if (config.test)
                Database.rollback(sp);

            system.debug('resultado::' + resultado);
            
        } 
        catch (Exception ex) 
        {
            //Excepcion no controlada, la devuelvo para todos los elementos
            generarResultadoExcepcionGeneral(resultado,ex);
        }

        //Fin
        return resultado;
    }

    //Relleno el error de la excpecion para todos los elementos a importar
    private static void generarResultadoExcepcionGeneral(List<ImportResult> resultados, Exception ex)
    {
        //Devolvemos el error para cada registro            
        for (Integer indiceError=0; indiceError<resultados.size(); indiceError++) 
        {
                                    
            resultados[indiceError].isSuccess = false;
            resultados[indiceError].id = null;
            resultados[indiceError].error = ex.getMessage();
            
        } 
    }
    //Genero el mapa con el resultado
    private static List<ImportResult> generarListaResultados(Integer numObjetos)
    {
        List<ImportResult> listaResultados = new List<ImportResult>();
        for (Integer i = 0 ; i<numObjetos; i++)
        {
            listaResultados.add(new ImportResult());
        }
        return listaResultados;
    }

    //Limpia el valor de la columna del fichero
    private static String quitaComillas(String columna)
    {
        String resultado;
        if (!String.isBlank(columna))
            resultado = columna.removeStart('"').removeEnd('"');

        return resultado;
    }

    //Completa los resultados finales con los resultados obtenidos de la importacion
    private static void completarResultados (Database.SaveResult[] resultados, List<ImportResult> resultado, Map<Integer, Integer> mapaCorrelaciones)
    {
        system.debug('completarResultados');
        for (Integer i = 0; i<resultados.size(); i++) 
        {
            Database.SaveResult sr = resultados[i];
            system.debug('sr::' + sr);
            //Añado el resultado en la posicion correspondiente            
            resultado[mapaCorrelaciones.get(i)].isSuccess = sr.isSuccess();
            resultado[mapaCorrelaciones.get(i)].id = sr.getId();
            if (!sr.getErrors().isEmpty())
                resultado[mapaCorrelaciones.get(i)].error = sr.getErrors()[0].getStatusCode() + ' ' + sr.getErrors()[0].getMessage() + ' ' + sr.getErrors()[0].getFields();

        }        
    }

    //Completa los resultados finales con los resultados obtenidos de la importacion
    private static void completarResultados (Database.DeleteResult[] resultados, List<ImportResult> resultado, Map<Integer, Integer> mapaCorrelaciones)
    {
        
        for (Integer i = 0; i<resultados.size(); i++) 
        {
            Database.DeleteResult sr = resultados[i];

            //Añado el resultado en la posicion correspondiente            
            resultado[mapaCorrelaciones.get(i)].isSuccess = sr.isSuccess();
            resultado[mapaCorrelaciones.get(i)].id = sr.getId();
            if (!sr.getErrors().isEmpty())
                resultado[mapaCorrelaciones.get(i)].error = sr.getErrors()[0].getStatusCode() + ' ' + sr.getErrors()[0].getMessage() + ' ' + sr.getErrors()[0].getFields();

        }        
    }

    //funcion que genera el mapa con el resultado de los lookups añadidos en configuracion
    private static Map<String,Map<String,String>> generarMapaLookups(List<Object> objects, ImportConfig config)
    {
        system.debug('generarMapaLookups');
        Map<String,Map<String,String>> mapaLookups = new  Map<String,Map<String,String>>();

        try 
        {
            if (config.mapeoLookups != null)
            {
                system.debug('config.mapaLookups::' + config.mapeoLookups);
                for(String key : config.mapeoLookups.keySet())
                {
                    system.debug('analizo lookup para ::' + key);
                    //Para cada columna que sea un lookup realizamos la query para recuperar sus valores
                    ImportLookup il = config.mapeoLookups.get(key);

                    system.debug('configuracion lookup ::' + il);
                    
                    //Obtengo la posicion de la columna lookup
                    Integer numColumnaLookup;
                    for (Integer indiceColumna = 0;indiceColumna < config.columnas.size();indiceColumna++ )
                    {
                        if (config.columnas[indiceColumna] == key)
                        {
                            numColumnaLookup = indiceColumna;
                        }
                    }
                    system.debug('numColumnaLookup::' + numColumnaLookup);
                    //Me recorro todas las columnas para recuperar los valores
                    Set<String> valores = new Set<String>();
                    for (Object linea : objects)
                    {
                        List<Object> valoresLinea = (List<Object>)linea;
                        if (!String.isBlank((String)valoresLinea[numColumnaLookup]))
                            valores.add('\'' + (String)valoresLinea[numColumnaLookup] + '\'');
                    }  
                    
                    List<String> listaValores = new List<String>(valores);
                    //Componemos query
                    String columnaSF = config.mapeo.get(key);
                    String query = 'SELECT ' + il.campoDestino + ',' + il.campoResultado + ' FROM ' + il.objetoDestino + ' WHERE ' + il.campoDestino + ' IN ';
                    query = query + '(' + String.join(listaValores, ',') + ')';
                    system.debug('QUERY:' + query);

                    List<sObject> resultadoQuery = Database.query(query);
                    Map<String,String> mapaResultadoQuery = new Map<String,String>();
                    if (!resultadoQuery.isEmpty())
                    {
                        for (sObject a : resultadoQuery)
                        {                            
                            if (!mapaResultadoQuery.containsKey((String)a.get(il.campoDestino)))
                            {
                                mapaResultadoQuery.put((String)a.get(il.campoDestino),(String) a.get(il.campoResultado));
                            }
                            else
                            {
                                //hay mas de un valor, damos el lookup como invalido
                                throw new LookupException('Valor duplicado de lookup');
                            }
                        }
                    }

                    mapaLookups.put(key,mapaResultadoQuery);
                    system.debug('mapaLookups::' + mapaLookups);
                }
            }
        } 
        catch (Exception ex) 
        {
            throw new LookupException('Error generando lookups ' + ex.getMessage());
        }
        return mapaLookups;

    }

    //Funcion que devuelve el valor del lookup si es que este existe para la columna procesada. 
    //Si existe lookup y no hay valor o este es vacio devolvera una excepcion para cortar el procesamiento de la linea
    private static String obtenerLookup(String nombreColumna, String valorColumna, Map<String,Map<String,String>> mapaLookups, ImportResult importResult)
    {
        String resultado = '';
        if (mapaLookups.containsKey(nombreColumna) && !String.isBlank(valorColumna))
        {
            //Ojo, esta columna tenia configurada un lookup, recuperamos su valor            
            if (mapaLookups.get(nombreColumna).containsKey(valorColumna))
            {
                String nuevoValor = mapaLookups.get(nombreColumna).get(valorColumna);
                if (!String.isBlank(nuevoValor))
                {
                    resultado = nuevoValor;
                }
                else
                {
                    //Contemplo este caso como excepcion?    
                    importResult.isSuccess = false;
                    importResult.error = 'El lookup proporcionado devuelve un valor vacio';
                    throw new LookupException ('Valor de lookup vacio'); //Lanzo excepcion para no continuar con el procesamiento de la fila
                }
            }        
            else
            {
                importResult.isSuccess = false;
                importResult.error = 'No existe valor para el lookup indicado';
                throw new LookupException ('Valor de lookup no existente'); //Lanzo excepcion para no continuar con el procesamiento de la fila
            }    
        }
        else 
        {
            resultado = valorColumna; //No lookup, devuelvo el mismo valor.
        }
        return resultado;
    }
    
    
    //Clase wrapper para devolver objetos de Salesforce
    public class ImportObject
    {
        @AuraEnabled
        public string name;
        @AuraEnabled
        public Boolean isUpdateable;
        @AuraEnabled
        public Boolean isCreatable;
        @AuraEnabled
        public Boolean isDeletable;        
    }

    //Clase wrapper para devolver campos
    global class ImportFields implements Comparable
    {
        @AuraEnabled
        public string label;       
        @AuraEnabled
        public string name;    

        //Se ordenan por nombre api
        global Integer compareTo(Object compareTo) 
        {
            if (name > ((ImportFields)compareTo).name)
                return 1;
            else
                return 0;
        }                   
    }

    //Clase wrapper para devolver el resultado de la operacion de importacion
    public class ImportResult
    {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public Boolean isSuccess;
        @AuraEnabled
        public String error;       
    }

    //Clase wrapper con la configuracion de la importacion
    public class ImportConfig
    {
        public List<String> columnas;
        public String objetoDestino;
        public String accion;
        public Map<String,String> mapeo;//Mapa Nombre columna -> Nombre Campo Salesforce
        public Map<String,ImportLookup> mapeoLookups;//Mapa nombre columna -> Configurcion Mapeo
        public Boolean test;
    }

    //Clase wrapper con la configuracion de un lookup
    public class ImportLookup
    {
        public String objetoDestino;
        public String campoDestino;
        public String campoResultado;
    }

    public class ImportException extends Exception {
    }

    public class LookupException extends Exception {
    }
        
}