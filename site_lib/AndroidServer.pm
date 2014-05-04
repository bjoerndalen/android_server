package AndroidServer;

use strict;
use warnings;
use Mouse;
use Testing::DAO::Group;
use Testing::VarRegistry;
use Testing::DAO::Student;

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
	return $result;
}

sub get_group_info {
	my ( $self, $params ) = @_;
	my $i_group = $params->{i_group};
	my $group   = undef;
	my $result;
	if ( defined $i_group ) {
		$result = Testing::DAO::Group::find_by_id($i_group);
		$result->{success}
		  ? $group = $result->{result}
		  : Testing::VarRegistry::add_error( $result->{error} );
		$result = {
			i_group         => $i_group,
			group_name      => $group->group_name(),
			is_system_group => $group->is_system_group(),
		};
	}
	return $result;
}

sub delete_student {
	my ( $self, $params ) = @_;
	my $i_student = $params->{i_student};
	my $result;
	if ( defined $i_student ) {
		$result = Testing::DAO::Student::remove($i_student);
		if ( !$result->{success} ) {
			Testing::VarRegistry::add_error( $result->{error} );
		}
	}
	return $result;
}

sub change_student_status {
	my ( $self, $params ) = @_;
	my $i_student = $params->{i_student};
	my $action    = $params->{action};
	my $result;
	if ( $action eq 'block' || $action eq 'undo' ) {
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
	return $result;
}

sub delete_group {
	my ( $self, $params ) = @_;
	my $i_group = $params->{i_group};
	my $result;
	if ( defined $i_group ) {
		$result = Testing::DAO::Group::find_by_id($i_group);
		if ( !$result->{success} ) {
			Testing::VarRegistry::add_error( $result->{error} );
		}
		if ( $result->{success} ) {
			my $group = $result->{result};
			$result = Testing::DAO::Group::remove($i_group);
			if ( !$result->{success} ) {
				Testing::VarRegistry::add_error( $result->{error} );
			}
		}
	}
	return $result;
}

sub edit_student {
	my ( $self, $params ) = @_;
	my $result =
	  ( defined $params->{id} )
	  ? Testing::DAO::Student::edit($params)
	  : Testing::DAO::Student::add($params);
	return $result;
}

sub get_group_count {
	my $self = shift;
	return Testing::DAO::Group::get_count();
}

sub get_student_info {
	my ( $self, $params ) = @_;
	my $i_student = $params->{i_student};
	my $result;
	if ( defined $i_student ) {
		$result = Testing::DAO::Student::find_by_id($i_student);
		if ( $result->{success} ) {
			$result = {
				login      => $result->{result}->login(),
				first_name => $result->{result}->first_name(),
				last_name  => $result->{result}->last_name(),
				comments   => $result->{result}->comments(),
				i_group    => $result->{result}->i_group()->id()
			};
		}
		else {
			Testing::VarRegistry::add_error( $result->{error} );
		}
	}
	return $result;
}

sub edit_stud_passwd {
	my ( $self, $params ) = @_;
	my $result;
	if ( defined $params->{id} && defined $params->{password} ) {
		$result = Testing::DAO::Student::edit_password($params);
	}
	return $result;
}

1;
