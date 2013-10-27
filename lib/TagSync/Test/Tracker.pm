package TagSync::Test::Tracker;

BEGIN {
  unlink "t/tracker/tracker.db";
  system 'sqlite3 t/tracker/tracker.db < schema/sqlite.sql';
  system 'sqlite3 t/tracker/tracker.db < t/tracker/data.sql';
}

use Plack::Test;
use TagSync::Tracker::API;
use TagSync::DB;

use Exporter qw{import};
our @EXPORT_OK = qw{&test_tracker};

sub test_tracker {
  my $db = TagSync::DB->new("dbi:SQLite:dbname=t/tracker/tracker.db");
  my $app = TagSync::Tracker::API->new(
    db => $db,
    user_auth => sub {
      $_[0]->parameters->{user_id}
    }
  );
  test_psgi
    app => $app->to_app,
    client => $_[0];
}

1;
