requires 'Plack';
requires 'JSON';
requires 'Digest::SHA1';
requires 'Text::Xslate';
requires 'DBIx::Connector';
requires 'PHP::Serialization';
requires 'Data::Dump';
requires 'DBD::mysql';
requires 'DBD::SQLite';
requires 'Digest::HMAC_SHA1';
requires 'Plack::Middleware::CrossOrigin';

on 'test' => sub {
	requires 'Test::More';
};

