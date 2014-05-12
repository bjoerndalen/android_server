package AndroidServer::Teacher;

use strict;
use warnings;
use Mouse;

use Testing::DAO::Category;
use Testing::DAO::Question;
use Testing::DAO::AssignedTest;
use Testing::DAO::Variant;
use Testing::DAO::Teacher;
use Testing::DAO::Test;

extends 'AndroidServer';

sub get_categories_count {
	my ( $self, $params ) = @_;
	return Testing::DAO::Category::get_count();
}

sub get_categories_list {
	my ( $self, $params ) = @_;
	my $categories_result = Testing::DAO::Category::get_list($params);
	my @page_data_array   = ();
	if ( defined $categories_result->{result} ) {
		@page_data_array = map {
			[
				$_->category_name(),
				$_->questions()->count(),
				$_->i_category(),
				$_->get_column('count_question') +
				  $_->get_column('details_count'),
			]
		} @{ $categories_result->{result} };
		my $result = Testing::DAO::Category::get_count();
		my $total_size = $result->{success} ? $result->{result} : 0;
		$result = {
			total_size => $total_size,
			items      => \@page_data_array,
		};
		return $result;
	}
	return {};
}

sub get_det_test_result {
	my ( $self, $params ) = @_;
	my $answer_status    = $params->{answer_status};
	my @page_data_array  = ();
	my $assigned_test_id = $params->{assigned_test_id};
	my $total_size       = 0;

	# find all questions and answers belong to this test
	my $answers_info = Testing::DAO::AssignedTest::get_answers($params);

	if ( defined( $answers_info->{result} ) ) {
		my @arr = @{ $answers_info->{result} };    # array with sorted answers;
		my $is_correct;

		# add data to result
		foreach (@arr) {

			# number of question
			my $question_number = $_->question_number();
			my $question_text   = $_->i_question->question_text();

			# check right or wrong answer
			my @variants;
			my @selected_variants = $_->selected_variants();
			if ( $_->i_question->question_type() eq 'text' ) {
				@variants = $_->i_question->variants();
				if ( !defined $selected_variants[0] ) {
					$is_correct = 'incorrect';
				}
				else {
					$is_correct = (
						Testing::DAO::AssignedTest::format_answer(
							$variants[0]->variant_text()
						  ) eq Testing::DAO::AssignedTest::format_answer(
							$selected_variants[0]->text_variant()
						  )
					) ? 'correct' : 'incorrect';
				}
			}
			else {
				@variants =
				  $_->i_question->variants()
				  ->search( { is_right_variant => 'true' }, {} )->all();
				$is_correct = Testing::DAO::Utils::compare_select_answers(
					{
						variants     => \@variants,
						selected_var => \@selected_variants
					}
				);
				next if ( !$is_correct->{success} );
				$is_correct =
				  ( $is_correct->{result} ) ? 'correct' : 'incorrect';
			}

			# get category of question
			my $category = $_->i_question->i_category;

			if (   ( $answer_status eq 'all' )
				|| ( $answer_status eq $is_correct ) )
			{
				push @page_data_array,
				  [
					(
						$question_number,
						$question_text,
						[ $category->i_category(), $category->category_name() ],
						$is_correct
					)
				  ];
			}
		}

		my $res = Testing::DAO::AssignedTest::get_test_question_count(
			$assigned_test_id);
		$total_size = $res->{success} == 1 ? $res->{result} : 0;
	}
	my $result = {
		total_size => $total_size,
		items      => \@page_data_array,
	};
	return $result;
}

sub get_group_result {
	my ( $self, $params ) = @_;
	my $size_result =
	  Testing::DAO::Test::get_question_count( $params->{test_id} );
	my $test_size = $size_result->{success} ? $size_result->{result} : 0;
	my $total_size = Testing::DAO::AssignedTest::get_tests_count($params);
	$total_size = $total_size->{success} ? $total_size->{result} : 0;
	my @page_data_array;

	my $result = Testing::DAO::AssignedTest::get_tests_by_group($params);

	if ( defined $result->{result} ) {
		@page_data_array = map {
			[
				$_->i_student()->last_name() . q{ }
				  . $_->i_student()->first_name(),
				$_->date_assigned(),
				$_->i_assigned_test_status()->status_name(),
				$_->i_assigned_test_status()->status_name() eq 'completed'
				? $_->score() . q{/} . $test_size
				: q{-},
				$_->i_assigned_test(),
			]
		} @{ $result->{result} };
	}
	return {
		total_size => $total_size,
		items      => \@page_data_array,
	};
}

sub get_question_answer_text {
	my ( $self, $params ) = @_;
	my $assigned_test_id = $params->{assigned_test_id};
	my $question_number  = $params->{question_number};
	my $question_text;
	my @variants;
	my @selected_variants;
	my @vars;
	my $text_variant_text;
	my $text_selected_text;
	my $is_text;

	if ( defined $assigned_test_id && defined $question_number ) {

		# get assigned test
		my $assigned_test_info =
		  Testing::DAO::AssignedTest::find_by_id($assigned_test_id);
		return unless $assigned_test_info->{success};
		my $assigned_test = $assigned_test_info->{result};

		# get answer for this question
		my $answer =
		  $assigned_test->answers()
		  ->search( { question_number => $question_number } )->single();

		# get question from answer
		my $question = $answer->i_question();
		if ( defined $question ) {
			$question_text = $question->question_text;

			# get answers text and status(correct or incorrect)
			@variants          = $question->variants();
			@selected_variants = $answer->selected_variants();
			$is_text           = 0;
			if ( $question->question_type() eq 'text' ) {
				$text_variant_text = $variants[0]->variant_text();
				if ( defined $selected_variants[0] ) {
					$text_selected_text = $selected_variants[0]->text_variant();
				}
				else {
					$text_selected_text = '[no variant was written]';
				}
				$is_text = 1;
			}

			# now pack into array for json parse
			@vars = map {
				my $curr_var = $_;
				{
					variant_text => $_->variant_text,
					is_right     => $_->is_right_variant(),
					is_selected  => (
						(
							grep { $_->i_variant()->id() == $curr_var->id() }
							  @selected_variants
						) ? 1 : 0
					),
					text_variant_text  => $text_variant_text,
					text_selected_text => $text_selected_text,
					is_text            => $is_text,
					is_right_text => Testing::DAO::AssignedTest::format_answer(
						$text_variant_text) eq
					  Testing::DAO::AssignedTest::format_answer(
						$text_selected_text)
				}
			} @variants;
		}
	}
	return { question_text => $question_text, variants => \@vars };
}

sub get_question_list {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Category::find_by_id( $params->{i_category} );
	my $total_size =
	  defined( $result->{result} )
	  ? Testing::DAO::Category::get_question_count(
		$result->{result}->i_category() )->{result}
	  : 0;
	$params->{category_id} = $params->{i_category};
	my @page_data_array;
	my $questions_result =
	  Testing::DAO::Question::get_questions_by_category($params);

	if ( defined $questions_result->{result} ) {
		@page_data_array = map {
			my $max_questions = $_->get_column('max_questions');
			my $answer_count  = $_->get_column('answer_count');
			my $can_delete    = (
				$answer_count + (
					  ( defined $max_questions )
					? ( ( $max_questions <= $total_size - 1 ) ? 0 : 1 )
					: 0
				)
			);
			[
				$_->question_text(), $_->question_type(),
				$_->i_question(),    $can_delete,
			],
		} @{ $questions_result->{result} };
	}
	return { total_size => $total_size, items => \@page_data_array };
}

sub get_test_list {
	my ( $self, $params ) = @_;
	my $count_result = Testing::DAO::Test::get_count();
	my $total_size =
	  defined( $count_result->{result} ) ? $count_result->{result} : 0;
	my @page_data_array;
	my $test_result = Testing::DAO::Test::get_list($params);
	if ( $test_result->{success} ) {
		@page_data_array = map {
			[
				$_->test_name(),
				$_->test_duration(),
				Testing::DAO::Test::get_question_count( $_->i_test() )->{result}
				? Testing::DAO::Test::get_question_count( $_->i_test() )
				  ->{result}
				: 0,
				$_->i_test(),
				$_->get_column('count_assigned_tests'),
			]
		} @{ $test_result->{result} };
	}
	return { total_size => $total_size, items => \@page_data_array };
}

sub get_variant_list {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Question::find_by_id( $params->{question_id} );
	my $total_size =
	  ( defined $result->{result} )
	  ? $result->{result}->variants()->count()
	  : 0;
	my @page_data_array;
	my $variants_result =
	  Testing::DAO::Variant::get_variants_by_question($params);
	if ( defined $variants_result->{result} ) {
		@page_data_array = map {
			[ $_->variant_text(), $_->is_right_variant(), $_->i_variant() ]
		} @{ $variants_result->{result} };
	}
	return { total_size => $total_size, items => \@page_data_array };
}

sub get_category_info {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Category::find_by_id( $params->{i_category} );
	my ( $category, $category_size );
	if ( $result->{success} ) {
		$category = $result->{result};
		$category_size =
		  Testing::DAO::Category::get_question_count( $category->i_category() )
		  ->{result};
	}
	else {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return {
		i_category    => $params->{i_category},
		category_name => $category->category_name(),
		category_size => $category_size,
	};
}

sub delete_question {
	my ( $self, $params ) = @_;
	my $result = {};
	if ( defined $params->{i_question} ) {
		$result = Testing::DAO::Question::remove( $params->{i_question} );
		Testing::VarRegistry::add_error( $result->{error} )
		  unless $result->{success};
	}
	return $result;
}

sub edit_category {
	my ( $self, $params ) = @_;
	my ( $i_category, $category_name ) =
	  ( $params->{i_category}, $params->{category_name} );
	my $result;
	if ( defined $category_name ) {
		unless ($i_category) {
			my $add = Testing::DAO::Category::add($params
			);
			$result = $add;
			if ( $add->{success} ) {
				$i_category = $add->{result};
			}
			else {
				Testing::VarRegistry::add_error( $add->{error} );
			}
		}
		else {
			my $edit = Testing::DAO::Category::edit($params);
			$result = $edit;
			Testing::VarRegistry::add_error( $edit->{error} )
			  unless $edit->{success};
		}
	}
	return $result;
}

sub delete_category {
	my ( $self, $params ) = @_;
	my $result;
	if ( defined $params->{i_category} ) {
		$result = Testing::DAO::Category::remove( $params->{i_category} );
		Testing::VarRegistry::add_error( $result->{error} )
		  unless ( $result->{success} == 1 );
	}
	return $result;
}

sub get_assigned_test_data {
	my ( $self, $params ) = @_;
	my $result_test =
	  Testing::DAO::AssignedTest::find_by_id( $params->{assigned_test_id} );
	Testing::VarRegistry::add_error( $result_test->{error} )
	  unless ( $result_test->{success} );
	my $assigned_test = $result_test->{result} ? $result_test->{result} : undef;

	my $test_data = {};
	if ( defined $assigned_test ) {
		$test_data->{test_name}     = $assigned_test->i_test()->test_name();
		$test_data->{assigned_date} = $assigned_test->date_assigned();
		$test_data->{teacher} =
		    $assigned_test->i_test()->i_teacher()->first_name() . q{ }
		  . $assigned_test->i_test()->i_teacher()->last_name();
		$test_data->{start_date}     = $assigned_test->time_started();
		$test_data->{completed_date} = $assigned_test->time_completed();
	}
	return $test_data;
}

sub get_all_groups {
	my ( $self, $params ) = @_;
	my @groups;
	my $groups_res = Testing::DAO::Group::get_all();
	if ( $groups_res->{success} ) {
		@groups = @{ $groups_res->{result} };
	}
	else {
		Testing::VarRegistry::add_error( $groups_res->{error} );
		return {};
	}
	my @items = map { [ $_->id(), $_->group_name(), ] } @groups;
	return { items => \@items };
}

sub get_all_tests {
	my $self = shift;
	my @tests;
	my $tests_res = Testing::DAO::Test::get_all();
	if ( $tests_res->{success} ) {
		@tests = @{ $tests_res->{result} };
	}
	else {
		Testing::VarRegistry::add_error( $tests_res->{error} );
		return {};
	}
	my @items =
	  map { [ $_->get_column('question_count'), $_->id(), $_->test_name() ] }
	  @tests;
	return { items => \@items };
}

sub assign_test {
	my ( $self, $params ) = @_;
	my $result = Testing::DAO::Test::assign_test($params);
	if ( !$result->{success} ) {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return $result;
}

sub edit_question {
	my ( $self, $params ) = @_;
	my $check_res = Testing::DAO::Variant::check_variants($params);
	if ( $check_res->{result} ) {
		my $save = undef;
		if (   !defined $params->{category_id}
			&& !defined $params->{question_type} )
		{
			$save = Testing::DAO::Question::edit_variants($params);
		}
		else {
			$save = Testing::DAO::Question::save_question($params);
		}
		if ( $save->{success} ) {
			return $save;
		}
		else {
			Testing::VarRegistry::add_error( $save->{error} );
		}
	}
	else {
		Testing::VarRegistry::add_error( $check_res->{error} );
	}
	return $check_res;
}

sub get_question_info {
	my ( $self, $params ) = @_;
	my $question;
	my $variants_not_editable;
	my $result = Testing::DAO::Question::find_by_id( $params->{i_question} );
	if ( $result->{success} ) {
		$question              = $result->{result};
		$variants_not_editable = $question->answers()->count();
	}
	else {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	return {
		i_question            => $question->id(),
		question_type         => $question->question_type(),
		question_text         => $question->question_text(),
		variants_not_editable => $variants_not_editable,
	};
}

sub get_question_types {
	my $self = shift;
	my @types_arr;
	my $types = Testing::DAO::Question::get_question_types();
	if ( defined $types->{result} ) {
		@types_arr = @{ $types->{result} };
	}
	else {
		Testing::VarRegistry::add_error('Cannot take question types.');
	}
	my @items = map { [ $_->{id}, $_->{label} ] } @types_arr;
	return { items => \@items };
}

sub get_text_question_answer {
	my ( $self, $params ) = @_;
	my $answer    = q{};
	my $answer_id = 0;
	my $question;
	my $variants_not_editable;
	my $result = Testing::DAO::Question::find_by_id( $params->{i_question} );
	if ( $result->{success} ) {
		$question = $result->{result};
	}
	else {
		Testing::VarRegistry::add_error( $result->{error} );
	}
	if ( defined $question ) {
		if ( $question->question_type() eq 'text' ) {
			$answer    = $question->variants()->single()->variant_text();
			$answer_id = $question->variants()->single()->id();
		}
	}
	return { answer => $answer, answer_id => $answer_id };
}

sub get_credentials {
	my ( $self, $params ) = @_;
	return Testing::DAO::Teacher::get_credentials($params);
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

sub edit_test {
	my ( $self, $params ) = @_;
	if ( defined $params->{id} ) {
		return Testing::DAO::Test::edit($params);
	}
	else {
		return Testing::DAO::Test::add($params);
	}
}

sub clone_test {
	my ( $self, $params ) = @_;
	return Testing::DAO::Test::clone($params);
}

sub replace_test_details {
	my ( $self, $params ) = @_;
	return Testing::DAO::Test::replace_details($params);
}

sub get_cat_questions_count {
	my ( $self, $params ) = @_;
	return Testing::DAO::Category::get_question_count( $params->{i_category} );
}

sub get_test_details {
	my ( $self, $params ) = @_;
	my $result_test = Testing::DAO::Test::find_by_id( $params->{i_test} );
	if ( ( defined $result_test ) and ( !$result_test->{success} ) ) {
		Testing::VarRegistry::add_error( $result_test->{error} );
		return;
	}
	my $test    = $result_test->{result};
	my @details = $test->test_details()->all();
	my @items   = map { $_->i_category()->id() } @details;
	return { items => \@items };
}

sub delete_test {
	my ( $self, $params ) = @_;
	return Testing::DAO::Test::remove( $params->{i_test} );
}
1;
