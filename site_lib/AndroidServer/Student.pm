package AndroidServer::Student;

use strict;
use warnings;
use Mouse;
use Testing::DAO::Test;
use Testing::DAO::Category;
use Testing::VarRegistry;
use Testing::DAO::AssignedTest;
use Testing::DAO::AssignedTestStatus;

extends 'AndroidServer';

sub get_assgned_test_details {
	my ( $self, $params ) = @_;
	my $i_test      = $params->{test_id};
	my $test_result = Testing::DAO::Test::find_by_id($i_test);
	if ( !$test_result->{success} ) {
		Testing::VarRegistry::add_error( $test_result->{error} );
	}
	my $result = {};
	if ( $test_result->{success} ) {
		my $test           = $test_result->{result};
		my $total_size     = $test->test_details()->count();
		my $details_result = Testing::DAO::Test::get_details_list($params);
		if ( $details_result->{success} == 0 ) {
			Testing::VarRegistry::add_error( $details_result->{error} );
		}
		my @page_data_array =
		  map { [ $_->i_category()->category_name(), $_->question_count() ] }
		  @{ $details_result->{result} };
		$result = {
			total_size => $total_size,
			items      => \@page_data_array,
		};
	}
	return $result;
}

sub get_test_list {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::AssignedTest::get_count_by_student($params);
	my $total_size = defined( $result->{result} ) ? $result->{result} : 0;
	my @page_data_array;
	my $categories_result =
	  Testing::DAO::AssignedTest::get_tests_by_student($params);
	if ( defined $categories_result->{result} ) {
		@page_data_array = map {
			[
				$_->i_test()->test_name(),
				$_->date_assigned(),
				$_->i_assigned_test_status()->status_name(),
				Testing::DAO::Test::get_question_count(
					$_->i_test()->i_test()
				  )->{result},
				$_->id()
			]
		} @{ $categories_result->{result} };
	}
	$result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;
}

sub get_assigned_test_details {
	my ( $self, $params ) = @_;
	my $i_assigned_test = $params->{i_assigned_test};
	my $result_test = Testing::DAO::AssignedTest::find_by_id($i_assigned_test);
	if ( !$result_test->{success} ) {
		Testing::VarRegistry::add_error( $result_test->{error} );
	}
	my $assigned_test = $result_test->{result} ? $result_test->{result} : undef;
	my $test = $assigned_test ? $assigned_test->i_test() : undef;
	my $test_data = { test_size => 0 };

	if ( defined $test ) {
		$test_data->{'test_status'} =
		  $assigned_test->i_assigned_test_status()->status_name();
		my $size_result = Testing::DAO::Test::get_question_count( $test->id() );
		if ( $size_result->{success} ) {
			$test_data->{'test_size'} = $size_result->{result};
		}
		else {
			Testing::VarRegistry::add_error( $size_result->{error} );
		}
	}

	my $start_btn_value = 'Start';
	if ( $test_data->{'test_status'} eq 'started' ) {
		$test_data->{'time_started'} = $assigned_test->time_started();
		$start_btn_value = 'Continue';
	}
	else {
		$test_data->{'time_started'} = 'Not started yet';
	}
	return $test_data;
}

sub get_credentials {
	my ( $self, $params ) = @_;
	return Testing::DAO::Student::get_credentials($params);
}

sub get_test_statuses {
	my $self          = shift;
	my $result        = Testing::DAO::AssignedTestStatus::get_all();
	my $test_statuses = defined( $result->{result} ) ? $result->{result} : [];
	return $test_statuses;
}

sub get_test_result {
	my ( $self, $params ) = @_;
	my $i_student       = $params->{i_student};
	my $i_assigned_test = $params->{i_assigned_test};
	my $test;
	if ( defined $i_assigned_test ) {
		my $result = Testing::DAO::AssignedTest::find_by_id($i_assigned_test);
		if ( $result->{success} ) {
			$test = $result->{result};
			if ( $test->i_student()->i_student() != $i_student ) {
				Testing::VarRegistry::add_error(
					'This test assigned to another student');
				return;
			}
			if ( $test->i_assigned_test_status()->status_name() ne 'completed' )
			{
				Testing::VarRegistry::add_error(
					'This test is not completed already');
				return;
			}
		}
		else {
			Testing::VarRegistry::add_error( $result->{error} );
			return;
		}
	}
	else {
		Testing::VarRegistry::add_error(
			'Test is undefined. Try to go this page through test list page.');
		return;
	}

	#get elapsed time
	my @date_time = split q{ }, $test->time_started();
	my ( $year1, $month1, $day1 ) = split q{-}, $date_time[0];
	my ( $hour1, $min1,   $sec1 ) = split q{:}, $date_time[1];
	@date_time = split( ' ', $test->time_completed() );
	my ( $year2, $month2, $day2 ) = split q{-}, $date_time[0];
	my ( $hour2, $min2,   $sec2 ) = split q{:}, $date_time[1];

	# for timelocal month is in range from 0 to 11
	my $time =
	  timelocal( $sec2, $min2, $hour2, $day2, $month2 - 1, $year2 ) -
	  timelocal( $sec1, $min1, $hour1, $day1, $month1 - 1, $year1 );
	my $time_elapsed = sprintf q{%02d:%02d:%02d},
	  $time / 3600, ( $time % 3600 ) / 60, $time % 60;

	my $score = 0;
	my $test_size =
	  Testing::DAO::Test::get_question_count( $test->i_test()->i_test() );
	my $right_answers = $test->score();
	if ( $test_size->{success} ) {
		$score = $right_answers . q{/} . $test_size->{result};
	}
	else {
		Testing::VarRegistry::add_error( $test_size->{error} );
	}
	my $result = {
		name      => $test->i_test()->test_name(),
		assigned  => $test->date_assigned(),
		started   => $test->time_started(),
		completed => $test->time_completed(),
		elapsed   => $time_elapsed,
		score     => $score,
	};
	return $result;
}

sub save_answer {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Answer::remove_answer($params);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
		return $result;
	}
	$result = Testing::DAO::Answer::add_answer($params);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
		return $result;
	}
	return $result;
}

sub start_test {
	my ( $self, $params ) = @_;
	my $student_id      = $params->{i_student};
	my $i_assigned_test = $params->{i_assigned_test};
	my $result = Testing::DAO::AssignedTest::find_by_id($i_assigned_test);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
		return $result;
	}
	my $assigned_test = $result->{result};
	if ( $student_id != $assigned_test->i_student()->id() ) {
		$result = Testing::DAO::Student::find_by_id($student_id);
		if ( !$result->{success} ) {
			Testing::VarRegistry::add_error( $result->{error} );
			return $result;
		}
		return {
			success => 0,
			error   => q{This is not a test for this student},
		};
	}
	if (
		$assigned_test->i_assigned_test_status()->status_name() eq 'completed' )
	{
		$result = Testing::DAO::Student::find_by_id($student_id);
		if ( !$result->{success} ) {
			Testing::VarRegistry::add_error( $result->{error} );
			return $result;
		}
	}
	$result = Testing::DAO::AssignedTest::start_test($i_assigned_test);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
		return $result;
	}
	return {
		success => 1,
		result =>
		  $assigned_test->i_test()->test_details()->get_column('question_count')
		  ->sum(),
	};
}

sub get_question {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Question::get_question($params);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
		return;
	}
	my $question = $result->{result};
	$result = {};
	if ( $question->question_type() eq 'text' ) {
		$result->{variant_id} =
		  $question->variants()->search( {} )->single()->id();
	}
	else {
		my @variants = ();
		foreach ( $question->variants() ) {
			push @variants,
			  {
				i_variant    => $_->i_variant(),
				variant_text => $_->variant_text()
			  };
		}
		$result->{variants} = \@variants;
	}
	$result->{question_text}   = $question->question_text();
	$result->{question_type}   = $question->question_type();
	$result->{question_number} = $params->{question_number};
	$result->{category_name}   = $question->i_category()->category_name();
	return { success => 1, result => $result };
}

sub get_answer {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Answer::get_answer($params);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return $result;
}

sub finish_test {
	my ( $self, $params ) = @_;
	my $i_assigned_test = $params->{i_assigned_test};
	my $result = Testing::DAO::AssignedTest::finish_test($i_assigned_test);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return $result;
}

# TODO Student specific functionality

1;
