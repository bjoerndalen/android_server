package AndroidServer::Admin;

use strict;
use warnings;
use Mouse;
use Testing::DAO::Admin;
use Testing::DAO::Teacher;

extends 'AndroidServer';

# TODO Admin specific functionality

sub get_admins_list {
	my ( $self, $params ) = @_;
	my $admins_result = Testing::DAO::Admin::get_list($params);
	my @admins        = ();
	if ( $admins_result->{success} ) {
		@admins = @{ $admins_result->{result} };
	}
	else {
		Testing::VarRegistry::add_error( $admins_result->{error} );
	}
	my @page_data_array = map {
		[
			$_->login(),
			$_->first_name(),
			$_->last_name(),
			$_->comments(),
			$_->i_admin(),
			$_->account_status(),
			( $_->get_column('admin_count') - 1 ) * (
				  $_->account_status() eq 'active'
				? $_->get_column('active_count') - 1
				: 1
			),
		]
	} @admins;
	my $result = Testing::DAO::Admin::get_count();
	my $total_size = $result->{success} ? $result->{result} : 0;
	$result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;

}

sub get_teachers_list {
	my ( $self, $params ) = @_;
	my $teachers_result = Testing::DAO::Teacher::get_list($params);
	my @teachers        = ();
	if ( $teachers_result->{success} ) {
		@teachers = @{ $teachers_result->{result} };
	}
	else {
		Testing::VarRegistry::add_error( $teachers_result->{error} );
	}
	my @page_data_array = map {
		[
			$_->login(),
			$_->first_name(),
			$_->last_name(),
			$_->comments(),
			$_->i_teacher(),
			$_->account_status(),
			$_->get_column('category_count') +
			  $_->get_column('tests_count') +
			  $_->get_column('assigned_tests_count'),
		]
	} @teachers;
	my $result = Testing::DAO::Teacher::get_count();
	my $total_size = $result->{success} ? $result->{result} : 0;
	$result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;
}

sub delete_teacher {
	my ( $self, $params ) = @_;
	my $i_teacher = $params->{i_teacher};
	my $result    = Testing::DAO::Teacher::find_by_id($i_teacher);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	if ( defined $i_teacher ) {
		$result = Testing::DAO::Teacher::remove($i_teacher);
		if ( !$result->{success} ) {
			Testing::VarRegistry::add_error( $result->{error} );
		}
	}
	return $result;
}

sub change_teacher_status {
	my ( $self, $params ) = @_;
	my $i_teacher = $params->{i_teacher};
	my $result;
	$result = Testing::DAO::Teacher::find_by_id($i_teacher);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	my $teacher = $result->{result};
	$result =
	  $teacher->account_status() eq 'active'
	  ? Testing::DAO::Teacher::block($i_teacher)
	  : Testing::DAO::Teacher::unblock($i_teacher);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return $result;
}

sub delete_admin {
	my ( $self, $params ) = @_;
	my $i_admin = $params->{i_admin};
	my $result  = Testing::DAO::Admin::find_by_id($i_admin);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	if ( $result->{success} ) {
		my $admin = $result->{result};
		$result = Testing::DAO::Admin::remove($i_admin);
	}
	return $result;
}

sub change_admin_status {
	my ( $self, $params ) = @_;
	my $i_admin = $params->{i_admin};
	my $result;
	$result = Testing::DAO::Admin::find_by_id($i_admin);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	my $admin = $result->{result};
	$result =
	  $admin->account_status() eq 'active'
	  ? Testing::DAO::Admin::block($i_admin)
	  : Testing::DAO::Admin::unblock($i_admin);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return $result;
}

sub edit_teacher {
	my ( $self, $params ) = @_;
	my $result =
	  ( defined $params->{id} )
	  ? Testing::DAO::Teacher::edit($params)
	  : Testing::DAO::Teacher::add($params);
	return $result;
}

sub get_teacher_info {
	my ( $self, $params ) = @_;
	my $i_teacher = $params->{i_teacher};
	my $result;
	if ( defined $i_teacher ) {
		$result = Testing::DAO::Teacher::find_by_id($i_teacher);
		if ( $result->{success} ) {
			$result = {
				login      => $result->{result}->login(),
				first_name => $result->{result}->first_name(),
				last_name  => $result->{result}->last_name(),
				comments   => $result->{result}->comments(),
			};
		}
		else {
			Testing::VarRegistry::add_error( $result->{error} );
		}
	}
	return $result;
}

sub edit_teacher_passwd {
	my ( $self, $params ) = @_;
	my $result;
	if ( defined $params->{id} && defined $params->{password} ) {
		$result = Testing::DAO::Teacher::edit_password($params);
	}
	return $result;
}

sub edit_admin {
	my ( $self, $params ) = @_;
	my $result =
	  ( defined $params->{id} )
	  ? Testing::DAO::Admin::edit($params)
	  : Testing::DAO::Admin::add($params);
	return $result;
}

sub get_admin_info {
	my ( $self, $params ) = @_;
	my $i_admin = $params->{i_admin};
	my $result;
	if ( defined $i_admin ) {
		$result = Testing::DAO::Admin::find_by_id($i_admin);
		if ( $result->{success} ) {
			$result = {
				login      => $result->{result}->login(),
				first_name => $result->{result}->first_name(),
				last_name  => $result->{result}->last_name(),
				comments   => $result->{result}->comments(),
			};
		}
		else {
			Testing::VarRegistry::add_error( $result->{error} );
		}
	}
	return $result;
}

sub edit_admin_passwd {
	my ( $self, $params ) = @_;
	my $result;
	if ( defined $params->{id} && defined $params->{password} ) {
		$result = Testing::DAO::Admin::edit_password($params);
	}
	return $result;
}

sub get_credentials {
	my ( $self, $params ) = @_;
	return Testing::DAO::Admin::get_credentials($params);
}

1;
