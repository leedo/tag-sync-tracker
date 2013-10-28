use TagSync::Server;
use Plack::Builder;
use JSON;

my $config = do {
  my $file = defined $ENV{TS_CONFIG} ? $ENV{TS_CONFIG} : 'conf/server.json';
  open my $fh, '<', $file;
  decode_json join "\n", <$fh>;
}; 

builder {
  enable "CrossOrigin",
    origins => $config->{tracker},
    headers => '*',
    methods => ["GET", "POST"];

  TagSync::Server->new(%$config)->to_app;
};
