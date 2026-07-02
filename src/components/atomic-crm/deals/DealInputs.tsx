import { required, useGetList, useTranslate } from "ra-core";
import { useWatch } from "react-hook-form";
import { AutocompleteArrayInput } from "@/components/admin/autocomplete-array-input";
import { ReferenceArrayInput } from "@/components/admin/reference-array-input";
import { ReferenceInput } from "@/components/admin/reference-input";
import { TextInput } from "@/components/admin/text-input";
import { NumberInput } from "@/components/admin/number-input";
import { DateInput } from "@/components/admin/date-input";
import { SelectInput } from "@/components/admin/select-input";
import { Separator } from "@/components/ui/separator";
import { useIsMobile } from "@/hooks/use-mobile";

import { contactOptionText } from "../misc/ContactOption";
import { useConfigurationContext } from "../root/ConfigurationContext";
import { AutocompleteCompanyInput } from "../companies/AutocompleteCompanyInput.tsx";

export const DealInputs = () => {
  const isMobile = useIsMobile();
  return (
    <div className="flex flex-col gap-8">
      <DealInfoInputs />

      <div className={`flex gap-6 ${isMobile ? "flex-col" : "flex-row"}`}>
        <DealLinkedToInputs />
        <Separator orientation={isMobile ? "horizontal" : "vertical"} />
        <DealMiscInputs />
      </div>
    </div>
  );
};

const DealInfoInputs = () => {
  return (
    <div className="flex flex-col gap-4 flex-1">
      <TextInput source="name" validate={required()} helperText={false} />
      <TextInput source="description" multiline rows={3} helperText={false} />
    </div>
  );
};

const DealLinkedToInputs = () => {
  const translate = useTranslate();
  return (
    <div className="flex flex-col gap-4 flex-1">
      <h3 className="text-base font-medium">
        {translate("resources.deals.inputs.linked_to")}
      </h3>
      <ReferenceInput source="company_id" reference="companies">
        <AutocompleteCompanyInput
          label="resources.deals.fields.company_id"
          validate={required()}
          modal
        />
      </ReferenceInput>

      <ReferenceArrayInput source="contact_ids" reference="contacts_summary">
        <AutocompleteArrayInput
          label="resources.deals.fields.contact_ids"
          optionText={contactOptionText}
          helperText={false}
        />
      </ReferenceArrayInput>
    </div>
  );
};

const DealMiscInputs = () => {
  const { dealCategories } = useConfigurationContext();
  const translate = useTranslate();
  const { data: brands } = useGetList("brands", {
    pagination: { page: 1, perPage: 50 },
    sort: { field: "id", order: "ASC" },
  });
  const { data: pipelineStages } = useGetList("pipeline_stages", {
    pagination: { page: 1, perPage: 200 },
    sort: { field: "position", order: "ASC" },
  });
  const brandId = useWatch({ name: "brand_id" });
  // Stage choices depend on the selected brand (xG has 8 stages, Onesport 6).
  // Compare as strings: the SelectInput stores brand_id as a string while
  // pipeline_stages.brand_id is a number.
  const stageChoices = brandId
    ? (pipelineStages ?? []).filter(
        (s) => String(s.brand_id) === String(brandId),
      )
    : [];
  return (
    <div className="flex flex-col gap-4 flex-1">
      <h3 className="text-base font-medium">
        {translate("resources.deals.field_categories.misc")}
      </h3>

      <SelectInput
        source="brand_id"
        choices={brands ?? []}
        optionText="name"
        optionValue="id"
        helperText={false}
        validate={required()}
      />
      <SelectInput
        source="category"
        choices={dealCategories}
        optionText="label"
        optionValue="value"
        helperText={false}
      />
      <NumberInput
        source="amount"
        defaultValue={0}
        helperText={false}
        validate={required()}
      />
      <DateInput source="expected_closing_date" helperText={false} />
      <SelectInput
        source="stage"
        choices={stageChoices}
        optionText="name"
        optionValue="slug"
        helperText={false}
        validate={required()}
      />
    </div>
  );
};
