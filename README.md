IMPORTATOR
------------

Bienvenido al importador de datos mas rapido y sencillo para Salesforce, realizado con Lightning Web Components para una integración con Salesforce perfecta.

El componente se puede agregar donde sea necesario, una pestaña, aplicacion, comunidad etc..

Esta estructurado como los ETLs mas potentes del mercado. Eligiendo, origen, destino, mapeos y visualización del resultado final.

Soporta ficheros CSV y EXCEL utilizando las librerias mas potentes del momento como son PAPAPARSE y SheetJS. De forma automatica podremos visualizar un preview de los registros a importar.
Realiza un filtrado de las filas incompletas.

<img src="https://raw.githubusercontent.com/VicNaranja/Importator/master/capturas/Origen.png" >


En la pestaña destino elegiremos el objeto de Salesforce y la operación que queramos realizar, inserción o actualización.
Los objetos y las acciones que se muestran seran siempre dependientes de los permisos del usuario.

<img src="https://raw.githubusercontent.com/VicNaranja/Importator/master/capturas/Destinos.png" >

En la pestaña mapeos, elegiremos el mapeo correspondiente entre las columnas de nuestro fichero y los campos de Salesforce. Pero, si nuestras columnas coinciden con los campos de Salesforce, bastará con pulsar el boton "Automatch" para realizar el mapeo instantaneo.

<img src="https://raw.githubusercontent.com/VicNaranja/Importator/master/capturas/mapeos2.png" >

Además cuenta con la posibilidad de realizar lookups a otros objetos de Salesforce y poder asi recuperar otros valores de Salesforce a partir de los valores dle fichero.
Mediante esta tecnica es posible también realizar la operación de upsert.

<img src="https://raw.githubusercontent.com/VicNaranja/Importator/master/capturas/lookups.png" >

En la ultima pestaña veremos el resultado final de la operación. Podremos elegir el tamaño del chunk para la importación y tendremos dos opciones para importar:

Test Importator -> Realiza la importación pero no hace commit de la operación. Perfecto para confirmar si los datos introducidos son correctos.

Inicio Importator -> Realiza la importación haciendo commit en Salesforce.

<img src="https://raw.githubusercontent.com/VicNaranja/Importator/master/capturas/Resultados.png" >

Además, se incluye una pagina visualforce que integra el componente mediente lightning out y asi lo puedas usuar en classic sin ningun problema.

<img src="https://raw.githubusercontent.com/VicNaranja/Importator/master/capturas/Classic.png" >