import { useEffect, useMemo, useState, type ReactNode } from "react";
import type { Identifier, InputProps } from "ra-core";
import {
  useGetIdentity,
  useGetList,
  useListContext,
  useTranslate,
} from "ra-core";
import { matchPath, useLocation } from "react-router";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { AutocompleteInput } from "@/components/admin/autocomplete-input";
import { CreateButton } from "@/components/admin/create-button";
import { ExportButton } from "@/components/admin/export-button";
import { List } from "@/components/admin/list";
import { ReferenceInput } from "@/components/admin/reference-input";
import { FilterButton } from "@/components/admin/filter-form";
import { SearchInput } from "@/components/admin/search-input";
import { SelectInput } from "@/components/admin/select-input";

import { useConfigurationContext } from "../root/ConfigurationContext";
import { TopToolbar } from "../layout/TopToolbar";
import { DealArchivedList } from "./DealArchivedList";
import { DealCreate } from "./DealCreate";
import { DealEdit } from "./DealEdit";
import { DealEmpty } from "./DealEmpty";
import { DealListContent } from "./DealListContent";
import { DealShow } from "./DealShow";
import { OnlyMineInput } from "./OnlyMineInput";
import type { StageChoice } from "./stages";

const DealList = () => {
  const { identity } = useGetIdentity();
  const { dealCategories } = useConfigurationContext();
  const translate = useTranslate();

  // Brand-aware pipeline: columns come from pipeline_stages (per brand), not the
  // legacy global dealStages config. Tabs switch the active brand.
  const { data: brands } = useGetList("brands", {
    pagination: { page: 1, perPage: 50 },
    sort: { field: "id", order: "ASC" },
  });
  const { data: pipelineStages } = useGetList("pipeline_stages", {
    pagination: { page: 1, perPage: 200 },
    sort: { field: "position", order: "ASC" },
  });
  const [brandId, setBrandId] = useState<Identifier | null>(null);

  const stagesByBrand = useMemo(() => {
    const map = new Map<Identifier, StageChoice[]>();
    (pipelineStages ?? []).forEach((s) => {
      const list = map.get(s.brand_id) ?? [];
      list.push({ value: s.slug, label: s.name });
      map.set(s.brand_id, list);
    });
    return map;
  }, [pipelineStages]);

  const brandTabs = useMemo(
    () => (brands ?? []).filter((b) => stagesByBrand.has(b.id)),
    [brands, stagesByBrand],
  );

  useEffect(() => {
    if (brandId == null && brandTabs.length) setBrandId(brandTabs[0].id);
  }, [brandTabs, brandId]);

  if (!identity || brandId == null) return null;

  const stages = stagesByBrand.get(brandId) ?? [];

  const dealFilters = [
    <SearchInput source="q" alwaysOn />,
    <ReferenceInput source="company_id" reference="companies">
      <AutocompleteInput
        label={false}
        placeholder={translate("resources.deals.fields.company_id")}
      />
    </ReferenceInput>,
    <WrapperField source="category" label="resources.deals.fields.category">
      <SelectInput
        source="category"
        label={false}
        emptyText="resources.deals.fields.category"
        choices={dealCategories}
        optionText="label"
        optionValue="value"
      />
    </WrapperField>,
    <OnlyMineInput source="sales_id" alwaysOn />,
  ];

  return (
    <div className="w-full">
      <Tabs
        value={String(brandId)}
        onValueChange={(v) => setBrandId(Number(v))}
        className="mb-4"
      >
        <TabsList>
          {brandTabs.map((b) => (
            <TabsTrigger key={String(b.id)} value={String(b.id)}>
              {b.name}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>
      <List
        key={String(brandId)}
        perPage={500}
        filter={{ brand_id: brandId, "archived_at@is": null }}
        title={false}
        sort={{ field: "index", order: "DESC" }}
        filters={dealFilters}
        actions={<DealActions />}
        pagination={null}
      >
        <DealLayout stages={stages} />
      </List>
    </div>
  );
};

const DealLayout = ({ stages }: { stages: StageChoice[] }) => {
  const location = useLocation();
  const matchCreate = matchPath("/deals/create", location.pathname);
  const matchShow = matchPath("/deals/:id/show", location.pathname);
  const matchEdit = matchPath("/deals/:id", location.pathname);

  const { data, isPending, filterValues } = useListContext();
  const hasFilters = filterValues && Object.keys(filterValues).length > 0;

  if (isPending) return null;
  if (!data?.length && !hasFilters)
    return (
      <>
        <DealEmpty>
          <DealShow open={!!matchShow} id={matchShow?.params.id} />
          <DealArchivedList />
        </DealEmpty>
      </>
    );

  return (
    <div className="w-full">
      <DealListContent stages={stages} />
      <DealArchivedList />
      <DealCreate open={!!matchCreate} />
      <DealEdit open={!!matchEdit && !matchCreate} id={matchEdit?.params.id} />
      <DealShow open={!!matchShow} id={matchShow?.params.id} />
    </div>
  );
};

const DealActions = () => (
  <TopToolbar>
    <FilterButton />
    <ExportButton />
    <CreateButton label="resources.deals.action.new" />
  </TopToolbar>
);

/**
 *
 * Used so that label of filters can be inferred for the select display,
 * but not be displayed when showing the input.
 */
const WrapperField = ({ children }: InputProps & { children: ReactNode }) =>
  children;

export default DealList;
