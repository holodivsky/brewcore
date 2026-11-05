@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Document'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'MaterialDocument' ]
@Search.searchable: true
define root view entity ZVHB_C_MaterialDocument
  provider contract transactional_query
  as projection on ZVHB_R_MaterialDocument
{
      @Search.defaultSearchElement: true
  key MaterialDocument,

      PostingDate,

      @Search.defaultSearchElement: true
      HeaderText,

      ReversedDocument,

      @EndUserText.label: 'Reversed By'
      _Reversal.MaterialDocument as ReversalDocument,

      CreatedBy,
      CreatedAt,

      _Item : redirected to composition child ZVHB_C_MaterialDocumentItem
}
