/** JSON:API envelope DTOs — mirrors the wire format from the Rails API */

export interface JsonApiResourceDto<TType extends string, TAttributes> {
  id: string;
  type: TType;
  attributes: TAttributes;
  relationships?: Record<string, JsonApiRelationshipDto>;
}

export interface JsonApiRelationshipDto {
  data: JsonApiResourceIdentifierDto | JsonApiResourceIdentifierDto[] | null;
}

export interface JsonApiResourceIdentifierDto {
  id: string;
  type: string;
}

export interface JsonApiCollectionDto<TType extends string, TAttributes> {
  data: JsonApiResourceDto<TType, TAttributes>[];
}

export interface JsonApiSingleDto<TType extends string, TAttributes> {
  data: JsonApiResourceDto<TType, TAttributes>;
}
