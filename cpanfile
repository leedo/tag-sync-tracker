requires 'Plack';
requires 'Plack::Middleware::ReverseProxy';
requires 'JSON';
requires 'Digest::SHA1';
requires 'Text::Xslate';
requires 'DBIx::Connector';
requires 'PHP::Serialization';
requires 'DBD::mysql';
requires 'DBD::SQLite';
requires 'Digest::HMAC_SHA1';
requires 'Starman';
requires 'Server::Starter';
requires 'Net::Server::SS::PreFork';
requires 'HTML::Scrubber';

on 'test' => sub {
	requires 'Test::More';
};

