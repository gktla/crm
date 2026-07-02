import { PlayerList } from "./PlayerList";
import { PlayerShow } from "./PlayerShow";

export default {
  list: PlayerList,
  show: PlayerShow,
  recordRepresentation: (record: { full_name?: string }) =>
    record?.full_name ?? "",
};
