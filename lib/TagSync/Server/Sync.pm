package TagSync::Server::Sync;

use parent 'Plack::Component';

use Plack::Util::Accessor qw{id token data_root};
use Plack::Request;
use TagSync::Web;
use Digest::HMAC_SHA1 qw{hmac_sha1_hex};
use Digest::SHA1 qw{sha1_hex};
use MIME::Base64 qw{decode_base64 encode_base64};
use URI::Escape;
use File::Copy;
use JSON;

sub prepare_req { Plack::Request->new($_[1]); }

get qr{/download/([^/]+)} => sub {
  my ($self, $req, $hash) = @_;

  die "token is required" unless defined $req->parameters->{token};

  my ($sig, $body) = split ":", decode_base64($req->parameters->{token}), 2;
  my $valid = hmac_sha1_hex $body, $self->token;

  die "invalid token" unless $valid eq $sig;

  my $data = decode_json $body;

  for (qw{filename time size}) {
    die "$_ is missing" unless defined $data->{$_};
  }

  # link works for 10 min
  die "token expired" if time - $data->{time} > (60 * 10);

  my $path = join "/", $self->data_root, $hash;
  open my $fh, '<', $path or die "unable to open $hash $!";

  if (defined $req->parameters->{exists}) {
    return api_response_ok;
  }

  my $size = (stat($path))[7];
  die "size does not match" unless $size == $data->{size};

  return [
    200, [
      'Content-Type', 'application/octet-stream',
      'Content-Disposition', qq{attachment; filename="$data->{filename}"},
      'Content-Length', $size,
    ], 
    $fh
  ];
};

post "/" => sub {
  my ($self, $req) = @_;

  die "token is required" unless defined $req->parameters->{token};

  my ($sig, $body) = split ":", decode_base64($req->parameters->{token}), 2;
  warn $self->token;
  my $valid = hmac_sha1_hex $body, $self->token;

  die "invalid token" unless $valid eq $sig;
  die "no file" unless defined $req->uploads->{file};

  my $upload = $req->uploads->{file};
  open my $fh, '<', $upload->path or die "unable to open upload";
  my $hash = Digest::SHA1->new->addfile($fh)->hexdigest;
  my $dest = $self->data_root . "/" . $hash;

  # if we already have it just pretend like it was uploaded
  if (!-e $dest) {
    move($upload->path, $dest) or die "unable to move file";
  }

  my $json = uri_escape encode_base64 encode_json {
    hash => $hash,
    size => $upload->size,
    filename => $upload->filename,
    server => $self->id,
    tags => $req->parameters->{tags},
    sig => sha1_hex(join "", $self->token, $upload->size, $hash),
  };

  my $return = $req->parameters->{return} . "?" . $json;

  if (defined $req->parameters->{is_js}) {
    return [
      200,
      ["Content-Type", "text/javascript"],
      [encode_json {location => $return}],
    ];
  }
  else {
    return [
      301,
      ["Location" => $return],
      ["Moved Permanently"],
    ];
  }
};

get "/ping" => sub {
  my ($self, $req) = @_;
  my $callback = $req->parameters->{callback};
  my $json = encode_json {success => "ok"};
  if ($callback) {
    $json = "$callback($json)";
  }
  [
    200,
    ["Content-Type", "text/javascript"],
    [$json],
  ];
};
