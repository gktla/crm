import { useListContext, useRecordContext } from "ra-core";
import { Show } from "@/components/admin/show";
import { ReferenceManyField } from "@/components/admin/reference-many-field";
import { ReferenceField } from "@/components/admin/reference-field";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const FUNNEL: { source: string; label: string }[] = [
  { source: "step_follow_back", label: "Follow back" },
  { source: "step_google_alert", label: "Google alert" },
  { source: "step_greetings", label: "Greetings" },
  { source: "step_sales_message", label: "Sales message" },
  { source: "step_phone_call", label: "Phone call" },
  { source: "step_zoom", label: "Zoom" },
  { source: "step_face_to_face", label: "Face to face" },
  { source: "step_contract", label: "Contract" },
];

const REL_LABEL: Record<string, string> = {
  owned: "Owned",
  current: "Current",
  loaned_in: "Loaned in",
  loaned_out: "Loaned out",
  target: "Target",
  national_team: "National team",
};

const PlayerHeader = () => {
  const record = useRecordContext();
  if (!record) return null;
  return (
    <div className="flex flex-col gap-1">
      <h1 className="text-2xl font-semibold">{record.full_name}</h1>
      <div className="flex flex-row flex-wrap gap-2 text-sm text-muted-foreground">
        {record.age_imported ? <span>Age {record.age_imported}</span> : null}
        {record.status ? <span>· {record.status}</span> : null}
      </div>
    </div>
  );
};

const FunnelSteps = () => {
  const record = useRecordContext();
  if (!record) return null;
  return (
    <div className="flex flex-row flex-wrap gap-2">
      {FUNNEL.map((s) => (
        <Badge
          key={s.source}
          variant={record[s.source] ? "default" : "outline"}
        >
          {s.label}
        </Badge>
      ))}
    </div>
  );
};

const RepresentationList = () => {
  const { data, isPending } = useListContext();
  if (isPending || !data?.length) return null;
  return (
    <div className="flex flex-col gap-1 text-sm">
      {data.map((rep) => (
        <div key={rep.id} className="flex flex-row gap-2">
          {rep.rep_code ? (
            <Badge variant="outline">{rep.rep_code}</Badge>
          ) : null}
          {rep.agent_expiry ? (
            <span className="text-muted-foreground">
              Agent expiry: {rep.agent_expiry}
            </span>
          ) : null}
        </div>
      ))}
    </div>
  );
};

const OrgAssignmentList = () => {
  const { data, isPending } = useListContext();
  if (isPending || !data?.length) return null;
  return (
    <div className="flex flex-col gap-2">
      {data.map((asg) => (
        <div key={asg.id} className="flex flex-row items-center gap-2 text-sm">
          <Badge variant="secondary">
            {REL_LABEL[asg.relationship_type] ?? asg.relationship_type}
          </Badge>
          <ReferenceField
            record={asg}
            reference="companies"
            source="org_id"
            link="show"
          />
        </div>
      ))}
    </div>
  );
};

export const PlayerShow = () => (
  <Show>
    <div className="flex flex-col gap-6 p-2">
      <PlayerHeader />

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Outreach funnel</CardTitle>
        </CardHeader>
        <CardContent>
          <FunnelSteps />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Clubs & national teams</CardTitle>
        </CardHeader>
        <CardContent>
          <ReferenceManyField
            reference="player_org_assignments"
            target="player_id"
          >
            <OrgAssignmentList />
          </ReferenceManyField>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="text-base">Representation</CardTitle>
        </CardHeader>
        <CardContent>
          <ReferenceManyField
            reference="player_representations"
            target="player_id"
          >
            <RepresentationList />
          </ReferenceManyField>
        </CardContent>
      </Card>

      <PlayerNotes />
    </div>
  </Show>
);

const PlayerNotes = () => {
  const record = useRecordContext();
  if (!record?.notes) return null;
  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Notes</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-sm whitespace-pre-wrap">{record.notes}</p>
      </CardContent>
    </Card>
  );
};
