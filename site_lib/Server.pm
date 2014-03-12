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
	default => sub { return { admins => [], teachers => [], students => [], } },
	lazy    => 1,
	reader  => 'get_reg_users',
	writer  => 'set_reg_users',
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

has 'supported_services' => (
	is       => 'rw',
	isa      => 'ArrayRef',
	required => 1,
	default  => sub { return [ q{teacher}, q{admin}, q{student}, ]; },
	lazy     => 1,
	reader   => 'get_services',
	writer   => 'set_services',
);

# Overriden method
sub process_request {
	my $self = shift;
	while (<STDIN>) {

		# TODO processing
	}
}

sub create_session {
	my $self = shift;
	my $role = shift;

	# TODO add UUID gen
	my $uuid = q{sdsdsdsd};
	my $key = sprintf q{%ss}, $role;
	push @{ $self->get_reg_users()->{$key} }, $uuid;
	return { success => 1, result => $uuid };
}

sub check_session {
	my $self = shift;
	my $uuid = shift;

	foreach my $role ( @{ $self->get_services() } ) {
		my $key = sprintf q{%ss}, $role;
		if ( scalar grep { $_ eq $uuid } @{ $self->get_reg_users()->{$key} } ) {
			$key =~ s/s$//sxm;
			return { success => 1, result => $key };
		}
	}
	return { success => 0, message => q{Session expired} };
}

# TODO Main Server Class
1;
