import { List } from "@/components/admin/list";
import { DataTable } from "@/components/admin/data-table";
import { ExportButton } from "@/components/admin/export-button";
import { SearchInput } from "@/components/admin/search-input";

import { TopToolbar } from "../layout/TopToolbar";

const PlayerListActions = () => (
  <TopToolbar>
    <ExportButton />
  </TopToolbar>
);

const playerFilters = [<SearchInput source="q" alwaysOn />];

export const PlayerList = () => (
  <List
    title="Players"
    perPage={50}
    sort={{ field: "full_name", order: "ASC" }}
    filters={playerFilters}
    actions={<PlayerListActions />}
  >
    <DataTable>
      <DataTable.Col source="full_name" label="Name" />
      <DataTable.Col source="age_imported" label="Age" />
      <DataTable.Col source="status" label="Funnel step" />
    </DataTable>
  </List>
);
