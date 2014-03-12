package Server;
use strict;
use warnings;
use Mouse;
use AndroidServer;
use AndroidServer::Teacher;

extends 'Net::Server::Fork';

has 'registred_user' => (
	is       => 'rw',
	isa      => 'HashRef',
	required => 0,
	default  => sub { return {}; },
	lazy     => 1,
	reader   => 'get_reg_users',
	writer   => 'set_reg_users',
);

has 'teacher_server' => (
	is       => 'rw',
	isa      => 'Any',
	required => 0,
	default  => sub { return AndroidServer::Teacher->new(); },
	lazy     => 1,
	reader   => 'get_teacher_serv',
	writer   => 'set_teacher_serv',
);

# Overriden method
sub process_request {
	my $self = shift;
	while (<STDIN>) {

		# TODO processing
	}
}

# TODO Main Server Class
1;
