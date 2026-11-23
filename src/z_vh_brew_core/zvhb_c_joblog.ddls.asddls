@EndUserText.label: 'Job Log'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VHB_JOB_LOG_QUERY'
@UI.headerInfo: {
  typeName: 'Log Message',
  typeNamePlural: 'Log Messages',
  title: { type: #STANDARD, value: 'JobName' },
  description: { type: #STANDARD, value: 'MessageText' }
}
@UI.presentationVariant: [{ sortOrder: [{ by: 'LoggedAt', direction: #DESC }, { by: 'ItemNumber', direction: #ASC }] }]
// Messages of the application log ZVHB_LOG, from the copy in table ZVHB_LOGMSG. Shows what the
// BrewCore jobs found and did, like the standard app Application Logs.
define custom entity ZVHB_C_JobLog
{
      @UI.facet: [{ id: 'Message', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Message', position: 10 }]
      @UI.hidden: true
  key LogHandle    : abap.char(22);

      @UI.lineItem: [{ position: 50, importance: #LOW }]
      @UI.identification: [{ position: 50 }]
      @EndUserText.label: 'Item'
  key ItemNumber   : abap.int4;

      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @UI.identification: [{ position: 10 }]
      @EndUserText.label: 'Logged At'
      LoggedAt     : abap.utclong;

      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @UI.identification: [{ position: 20 }]
      @EndUserText.label: 'Job'
      JobName      : abap.char(40);

      @UI.selectionField: [{ position: 10 }]
      @UI.identification: [{ position: 25 }]
      @Consumption.filter: { selectionType: #SINGLE, multipleSelections: false }
      @EndUserText.label: 'Log Subobject'
      Subobject    : abap.char(20);

      @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
      @UI.identification: [{ position: 30 }]
      @EndUserText.label: 'Plant'
      ExternalId   : abap.char(100);

      @UI.lineItem: [{ position: 35, importance: #HIGH, criticality: 'Criticality', criticalityRepresentation: #WITH_ICON }]
      @UI.identification: [{ position: 35, criticality: 'Criticality', criticalityRepresentation: #WITH_ICON }]
      @EndUserText.label: 'Severity'
      SeverityText : abap.char(20);

      @UI.hidden: true
      Criticality  : abap.int1;

      @UI.lineItem: [{ position: 40, importance: #HIGH }]
      @UI.identification: [{ position: 40 }]
      @EndUserText.label: 'Message'
      MessageText  : abap.char(255);
}
