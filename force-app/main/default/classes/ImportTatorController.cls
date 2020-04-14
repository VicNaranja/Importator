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
            if (describe.isUpdateable() || describe.isCreateable())
            {
                ImportObject io = new ImportObject();
                io.name = objs.get(key).getDescribe().getName();
                io.isCreatable = describe.isCreateable();
                io.isUpdateable = describe.isUpdateable();
                resultado.add(io);
            }
        }
        return resultado;

    }

    // Recupera todos los objetos de Salesforce
    @AuraEnabled (cacheable=true)
    public static List<ImportFields> getFieldsSalesforce(String fieldName, String action)
    {
        system.debug('getFieldsSalesforce::' + fieldName + ' ' + action);
        if (String.isBlank(fieldName))
            return null;

        List<ImportFields> resultado = new List<ImportFields>();

        Map<string, SObjectType> objs = schema.getGlobalDescribe();
        for(string key: objs.keySet())
        {
            if (key == fieldName)
            {
                system.debug('Objeto encontrado::' + fieldName);
                DescribeSObjectResult describe = objs.get(key).getDescribe();                
                Map<String, Schema.SObjectField> fieldMap =  describe.fields.getMap();

                for(String keyField : fieldMap.keySet())
                {
                    DescribeFieldResult fieldDescribe = fieldMap.get(keyField).getDescribe();
                    system.debug('fieldDescribe::' + fieldDescribe.getName());

                    if (fieldDescribe.isAccessible())
                    {
                        if (action == 'Insertar' &&  fieldDescribe.isCreateable() || (action == 'Actualizar' && (fieldDescribe.isUpdateable() || fieldDescribe.getName() == 'Id')  ))
                        {
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
        List<ImportResult> resultado = new List<ImportResult>();

        //Parseamos objetos
        List<Object> listaObjetos = (List<Object>)JSON.deserializeUntyped(objects);

        //Parseamos configuracion
        ImportConfig config = (ImportConfig)JSON.deserialize(definicion, ImportConfig.class);
        
        //Recuperamos definicion de obeto de salesforce a importar
        Schema.SObjectType objetoSF = Schema.getGlobalDescribe().get(config.objetoDestino);
        //Recuperamos definicion de campos del objeto
        Map<String, Schema.SObjectField> fieldsMap = objetoSF.getDescribe().fields.getMap();

        //Creamos objeto a insertar/actualizar
        List<SObject> listaObjetosImportar = new List<SObject>();

        /************************************************************************** PARTE PARSEO ***************************************************** */
        //Procesamos fichero
        Integer i = 0;//fila
        Integer k = 0;//columna       
        for (Object l : listaObjetos) 
        {
            system.debug('Proceso linea ' + i + ' ' + l);
            //Creo el objeto correspondiente
            sObject nuevoObjeto = objetoSF.newSObject();
            
            k=0;
            //Para cada columna
            for (Object c : (List<Object>)l) 
            {
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
            listaObjetosImportar.add(nuevoObjeto);
            i++;
        }

        /************************************************************************** PARTE IMPRTACION ***************************************************** */
        Savepoint sp = Database.setSavepoint();
        
        try
        {
             //Insertamos o actualizamos segun operacion
            if (config.accion == 'Insertar')
            {
                resultado = convertResult(Database.insert(listaObjetosImportar, false));           
            }
            else if (config.accion == 'Actualizar')
            {            
                resultado = convertResult(Database.update(listaObjetosImportar, false));  
            }
            else 
            {
                throw new ImportException('accion no esperada');
            }

        } 
        catch (Exception ex)
        {
            //Devolvemos el error para cada registro            
            for (Integer indiceError=0;indiceError<listaObjetosImportar.size();indiceError++) {
                ImportResult ir = new ImportResult();
                ir.isSuccess = false;
                ir.id = null;
                ir.error = ex.getMessage();
                resultado.add(ir);
            } 
        }
       

        //Si es un test hacemos rollback
        if (config.test)
            Database.rollback(sp);


        //Fin
        return resultado;

    }


    //Limpia el valor de la columna del fichero
    private static String quitaComillas(String columna)
    {
        String resultado;
        if (!String.isBlank(columna))
            resultado = columna.removeStart('"').removeEnd('"');

        return resultado;
    }


    private static List<ImportResult> convertResult (Database.SaveResult[] resultados)
    {
        List<ImportResult> resultado = new List<ImportResult>();

        for (Database.SaveResult sr : resultados) {
            ImportResult i = new ImportResult();
            i.isSuccess = sr.isSuccess();
            i.id = sr.getId();
            if (!sr.getErrors().isEmpty())
                i.error = sr.getErrors()[0].getStatusCode() + ' ' + sr.getErrors()[0].getMessage() + ' ' + sr.getErrors()[0].getFields();
            resultado.add(i);
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
    }

    //Clase wrapper para devolver campos
    global class ImportFields implements Comparable
    {
        @AuraEnabled
        public string label;       
        @AuraEnabled
        public string name;    

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
        public Map<String,String> mapeo;
        public Boolean test;
    }

    public class ImportException extends Exception {
    }

        
}