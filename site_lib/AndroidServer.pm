package AndroidServer;

use strict;
use warnings;
use Mouse;
use Testing::DAO::Group;
use Testing::VarRegistry;
use Testing::DAO::Student;

# TODO Class of Android Server

# input: hashref with group_id,	field, rows, page, sorted_type fields
# output: hashref with count and items
sub get_groups_list {
	my ( $self, $params ) = @_;
	my $groups_result = Testing::DAO::Group::get_list($params);
	my @groups;
	if ( $groups_result->{success} ) {
		@groups = @{ $groups_result->{result} };
	}
	else {
		Testing::VarRegistry::add_error( $groups_result->{error} );
	}

	my @page_data_array = map {
		my $cannot_delete =
		  $_->get_column('cannot_delete') + $_->is_system_group();
		[ $_->group_name(), $_->id(), $cannot_delete, ]
	} @groups;
	my $result = Testing::DAO::Group::get_count();
	my $total_size = $result->{success} ? $result->{result} : 0;
	$result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;
}

sub get_students_by_group {
	my ( $self, $params ) = @_;
	my $students_result = Testing::DAO::Student::get_students_by_group($params);
    my @page_data_array;
	if ( defined $students_result->{result} ) {
		@page_data_array = map( [
				$_->login(),          $_->first_name(),
				$_->last_name(),      $_->comments(),
				$_->account_status(), $_->id(),
				$_->get_column('can_delete'),
			],
			@{ $students_result->{result} } );
	}
	my $result =
	  Testing::DAO::Student::get_count_by_group( $params->{group_id} );
	my $total_size = ( defined $result->{result} ) ? $result->{result} : 0;
	$result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;
}

sub get_students_list {
	my ( $self, $params ) = @_;
	my $students_result = Testing::DAO::Student::get_list($params);
	my @page_data_array;
	if ( $students_result->{success} ) {
		my @students = @{ $students_result->{result} };
		@page_data_array = map( [
				$_->login(),          $_->first_name(),
				$_->last_name(),      $_->i_group->group_name(),
				$_->comments(),       $_->i_student(),
				$_->account_status(), $_->get_column('can_delete'),
			],
			@students );
	}
	my $result = Testing::DAO::Student::get_count();
	my $total_size = $result->{success} ? $result->{result} : 0;
	$result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;
}


sub edit_group {
	my ( $self, $params ) = @_;
	my $i_group    = $params->{i_group};
	my $i_student  = $params->{i_student};
	my $group_name = $params->{group_name};
	my $action     = $params->{action};
	my $result;
	if ( defined $group_name ) {
		$result =
		  ( defined $i_group )
		  ? Testing::DAO::Group::edit(
			{
				id         => $i_group,
				group_name => $group_name
			}
		  )
		  : Testing::DAO::Group::add($group_name);
		$result->{success}
		  ? $i_group = $result->{result}
		  : Testing::VarRegistry::add_error( $result->{error} );
	}

	my $group = undef;
	if ( defined $i_group ) {
		$result = Testing::DAO::Group::find_by_id($i_group);
		$result->{success}
		  ? $group = $result->{result}
		  : Testing::VarRegistry::add_error( $result->{error} );
	}

	if ( defined $i_student && defined $action ) {
		if ( $action eq 'delete' ) {
			$result = Testing::DAO::Student::remove($i_student);
			if ( !$result->{success} ) {
				Testing::VarRegistry::add_error( $result->{error} );
			}
		}
		elsif ( $action eq 'block' || $action eq 'undo' ) {
			$result = Testing::DAO::Student::find_by_id($i_student);
			if ( !$result->{success} ) {
				Testing::VarRegistry::add_error( $result->{error} );
			}
			my $student = $result->{result};
			$result =
			  $student->account_status() eq 'active'
			  ? Testing::DAO::Student::block($i_student)
			  : Testing::DAO::Student::unblock($i_student);
			if ( !$result->{success} ) {
				Testing::VarRegistry::add_error( $result->{error} );
			}
		}
	}
	return $result;
}

1;
