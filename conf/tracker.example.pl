use TagSync::Auth::PunBB;

{
  db   => TagSync::DB->new("dbi:SQLite:dbname=tracker.db"),
  auth => TagSync::Auth::PunBB->new(
    TagSync::DB->new("dbi:mysql:dbname=punbb", "punbb", "punbb")
  ),
}
