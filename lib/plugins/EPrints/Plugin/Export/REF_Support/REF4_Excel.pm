package EPrints::Plugin::Export::REF_Support::REF4_Excel;

use EPrints::Plugin::Export::REF_Support;
@ISA = ( "EPrints::Plugin::Export::REF_Support" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "REF Support - Excel";
	$self->{accept} = [ 'report/ref4' ];
	$self->{suffix} = ".xlsx";
	$self->{mimetype} = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

	my $rc = EPrints::Utils::require_if_exists('Excel::Writer::XLSX');
	unless ($rc)
	{
		$self->{advertise} = $self->{enable} = 0;
		$self->{error} = 'Unable to load required module Excel::Writer::XLSX';
	}
	
	$self->{advertise} = $self->{enable} = 1;
	
	return $self;
}

sub output_list
{
        my( $plugin, %opts ) = @_;
	
	my $session = $plugin->{session};

	my $output;
	open(my $FH,'>',\$output);
	
	my $predefined_workbook = 0;
	my $workbook;

	if( defined $opts{fh} && ref $opts{fh} eq "Excel::Writer::XLSX" )
        {
                $predefined_workbook = 1; # flag the fact we have been given a workbook to work with
                $workbook = $opts{fh};
        }
	elsif (defined $opts{fh})
	{
		binmode($opts{fh});
		$workbook = Excel::Writer::XLSX->new(\*{$opts{fh}});
		die("Unable to create spreadsheet: $!")unless defined $workbook;
	}
	else
	{
		$workbook = Excel::Writer::XLSX->new($FH);
		die("Unable to create spreadsheet: $!")unless defined $workbook;
	}

	#$workbook->set_properties( utf8 => 1 );

	# headers / field list
	my $ref4a = [ 'UKPRN', 'UnitOfAssessment', 'MultipleSubmission', 'Year', 'DegreesAwarded' ];
	my $ref4b = [ 'UKPRN', 'UnitOfAssessment', 'MultipleSubmission', 'Source' ];
	my $ref4c = [ 'UKPRN', 'UnitOfAssessment', 'MultipleSubmission', 'Source' ];
	foreach my $year ( @{$session->config( 'ref_support', 'income_years' )} )
	{
		push @$ref4b, 'Income' . $year;
		push @$ref4c, 'Income' . $year;
	}

	my $columns = {
		'ref4a' => $ref4a,
		'ref4b' => $ref4b,
		'ref4c' => $ref4c,
	};

	my $worksheets = {};
	foreach my $report ( 'ref4a', 'ref4b', 'ref4c' )
	{
		my $col_id = 0;
		$worksheets->{$report} = $workbook->add_worksheet( $session->phrase( "ref/report/excel:$report" ) ) or next;
		foreach( @{ $columns->{$report} || [] } )
		{
			$worksheets->{$report}->write( 0, $col_id++, $_ );
		}
	}	

	my $institution = $session->config( 'ref', 'institution' ) || $session->phrase( 'archive_name' );

	# REF4: iterate over the entire list, pre-calculate what needs to be
	# $degrees->{$uoa}->{$year} = 12;
	# $income->{$uoa}->{$source_id}->{$year} = 123_456;
	# $multiple->{$uoa} = 1 or 0 if it's multiple submission;

	my $degrees = {};
	my $incomes = {};
	my $incomes_kind = {};
	my $multiple = {};
	my @uoas;
	my $current_uoa = undef;

	$opts{list}->map( sub {
		my( undef, undef, $dataobj ) = @_;

		# must know the year
		my $year = $dataobj->value( 'year' ) or return;
		
		my $uoa = $plugin->get_current_uoa( $dataobj );
		return unless( defined $uoa );

		if( !defined $current_uoa || ( "$current_uoa" ne "$uoa" ) )
		{
			$current_uoa = $uoa;
			push @uoas, $uoa;
		}

		# degrees awarded
		$degrees->{$uoa}->{$year} = $dataobj->value( 'degrees' );

		# incomes
		foreach( @{$dataobj->value( 'income' )||[]} )
		{
			my $src = $_->{source} or next;
			my $value = $_->{value} or next;
			$src =~ s/^(\d+)_.*$/$1/g;
			$incomes->{$uoa}->{int($src)}->{$year} += $value;
		}

		# incomes in kind
		foreach( @{$dataobj->value( 'income_in_kind' )||[]} )
		{
			my $src = $_->{source} or next;
			my $value = $_->{value} or next;
			$src =~ s/^(\d+)_.*$/$1/g;
			$incomes_kind->{$uoa}->{int($src)}->{$year} += $value;
		}
	} );

	my %rows = map { $_ => 1 } ( 'ref4a', 'ref4b', 'ref4c' );

	foreach my $uoa (@uoas)
	{
		my( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa );
		next unless( defined $hefce_uoa_id );

		# REF4a
		foreach my $year (sort keys %{$degrees->{$uoa}||{}} )
		{
			my $total = $degrees->{$uoa}->{$year};
			next unless( EPrints::Utils::is_set( $total ) && $total =~ /^\d+$/ );

			if( $worksheets->{ref4a} )
			{
				my $col_id = 0;
				$worksheets->{ref4a}->write( $rows{ref4a}, $col_id++, $_ ) for( $institution, $hefce_uoa_id, $is_multiple, $year, $plugin->escape_value( $total ) );
				$rows{ref4a}++;
			}
		}

		# REF4b
		foreach my $source (sort keys %{$incomes->{$uoa}||{}})
		{
			my @income_years;
			foreach my $year ( @{$session->config( 'ref_support', 'income_years' )} )
			{
				my $value = $incomes->{$uoa}->{$source}->{$year};
				$value ||= '0';
				push @income_years, $plugin->escape_value( $value );
			}

			if( $worksheets->{ref4b} )
			{
				my $col_id = 0;
				$worksheets->{ref4b}->write( $rows{ref4b}, $col_id++, $_ ) for( $institution, $hefce_uoa_id, $is_multiple, $source, @income_years );
				$rows{ref4b}++;
			}
		}

		# REF4c
		foreach my $source (sort keys %{$incomes_kind->{$uoa}||{}})
		{
			my @income_years;
			foreach my $year ( @{$session->config( 'ref_support', 'income_years' )} )
			{
				my $value = $incomes_kind->{$uoa}->{$source}->{$year};
				$value ||= '0';
				push @income_years, $plugin->escape_value( $value );
			}
		
			if( $worksheets->{ref4c} )
			{	
				my $col_id = 0;
				$worksheets->{ref4c}->write( $rows{ref4c}, $col_id++, $_ ) for( $institution, $hefce_uoa_id, $is_multiple, $source, @income_years );
				$rows{ref4c}++;
			}
		}
	}

	$workbook->close unless $predefined_workbook;

	if( $predefined_workbook )
        {
                # we were given a workbook (almost certainly from the complete report process) so we should return it
                return $workbook;
        }
	elsif (defined $opts{fh})
	{
		return undef;
	}

	return $output;
}

sub escape_value
{
	my( $plugin, $value ) = @_;

	return "" unless( defined EPrints::Utils::is_set( $value ) );

	# if value is a pure number, then add ="$value" so that Excel stops the auto-formatting (it'd turn 123456 into 1.23e+6)
	#if( $value =~ /^\d+$/ )
	#{
	#	return "=\"$value\"";
	#}

	return $value;
}


1;
