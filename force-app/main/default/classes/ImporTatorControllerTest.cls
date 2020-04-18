/**
* TEST ImportTatorController
**
*/
@isTest
public class ImporTatorControllerTest 
{
    @isTest static void getObjectsSalesforce() 
	{
        List<ImportTatorController.ImportObject> listaObjetos = ImportTatorController.getObjectsSalesforce();
        system.assert(!listaObjetos.isempty());
    }

    @isTest static void getFieldsSalesforce() 
	{
        List<ImportTatorController.ImportFields> listaCampos = ImportTatorController.getFieldsSalesforce('Account', 'Insertar', true);
        system.assert(!listaCampos.isempty());
    }

    @isTest static void insertData() 
	{
        Account a = new Account();
        a.Name = 'Dickenson plc';
        insert a;

        Account a2 = new Account();
        a2.Name = 'Omni Consumer Products';
        insert a2;


        //Generamos datos de prueba
        String data = '[["Pepe","Luis","pepeluis@hotmail.com","Omni Consumer Products"],["Mikel","Perez","mikel@hotmail.com","Dickenson plc"]]';

        String configLookup = '{"columnas":["FirstName","LastName","Email","NombreAccount"],"objetoDestino":"Contact","accion":"Insertar","mapeo":{"FirstName":"FirstName","LastName":"LastName","Email":"Email","NombreAccount": "AccountId"}, "mapeoLookups" : {"NombreAccount" : {"objetoDestino": "Account","campoDestino" : "Name","campoResultado" : "Id"}},"test":false}';
        
        
        List<ImportTatorController.ImportResult>  resultados = ImportTatorController.importData(data,configLookup);

        system.debug('resultados:: ' + resultados);
        for (ImportTatorController.ImportResult result : resultados)
        {
            System.assert(result.isSuccess);
        }

    }

    
    @isTest static void deleteData() 
	{
        Account a = new Account();
        a.Name = 'Dickenson plc';
        insert a;

        Account a2 = new Account();
        a2.Name = 'Omni Consumer Products';
        insert a2;


        //Generamos datos de prueba
        String data = '[["'+ a.Id +'"],["' + a2.Id+ '"]]';

        String configLookup = '{"columnas":["Id"],"objetoDestino":"Account","accion":"Eliminar","mapeo":{"Id":"Id"},"test":false}';
        
        
        List<ImportTatorController.ImportResult>  resultados = ImportTatorController.importData(data,configLookup);

        system.debug('resultados:: ' + resultados);
        for (ImportTatorController.ImportResult result : resultados)
        {
            System.assert(result.isSuccess);
        }

    }


}
