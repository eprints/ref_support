package EPrints::Plugin::Export::REF_Support::REF_Excel;

use EPrints::Plugin::Export::REF_Support;
@ISA = ( "EPrints::Plugin::Export::REF_Support" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my $self = $class->SUPER::new( %opts );

	$self->{name} = "REF Support - Excel";
	$self->{suffix} = ".xlsx";
	$self->{mimetype} = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
	$self->{is_hierarchical} = 0;

	my $rc = EPrints::Utils::require_if_exists('Excel::Writer::XLSX');
	unless ($rc)
	{
		$self->{advertise} = $self->{enable} = 0;
		$self->{error} = 'Unable to load required module Excel::Writer::XLSX';
	}
	
	$self->{advertise} = $self->{enable} = 1;
	
	return $self;
}


# Main method - called by the appropriate Screen::Report plugin
sub output_list
{
	my( $plugin, %opts ) = @_;

	my $output;
	open(my $FH,'>',\$output);

	my $predefined_workbook = 0;
	my $workbook;
	if( defined $opts{fh} && ref $opts{fh} eq "Excel::Writer::XLSX" )
	{
		binmode(\*STDOUT);
		$predefined_workbook = 1; # flag the fact we have been given a workbook to work with
		$workbook = $opts{fh};
	}
	elsif( defined $opts{fh} )
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

	#$workbook->set_properties( utf8 => 1 ) unless $predefined_workbook;
	my $session = $plugin->{session};

	my $worksheet = $workbook->add_worksheet( $session->phrase( 'ref/report/excel:'.$plugin->get_report ) );

	# the appropriate REF::Report::{report_id} plugin will build up the list: 
	$plugin->{benchmark} = $opts{benchmark};

	my $institution = $session->config( 'ref', 'institution' ) || $session->phrase( 'archive_name' );
	my $action = $session->config( 'ref', 'action' ) || 'Update';

	my $report = $plugin->get_report();

	# headers / field list
	my @cols;
	my $commons = {};
	if( grep { $report eq $_ } @{$plugin->{session}->config( 'ref_2021_reports' )} )
	{
		@cols = ("UKPRN","UnitOfAssessment","MultipleSubmission", @{$plugin->ref_fields_order()} );
		# common fields/values
                $commons = {
                        UKPRN => $institution,
                };
	}
	else
	{
		@cols = ("institution","unitOfAssessment","multipleSubmission","action", @{$plugin->ref_fields_order()} );
		# common fields/values
		$commons = {
			institution => $institution,
			action => $action,
		};
	}
    
    my $hierarchical_fields = $plugin->{session}->config( 'ref', $plugin->get_report, 'hierarchical_fields' );
	my $col_id = 0;
	foreach my $col (@cols)
	{
        next if( grep { $col eq $_ } @{$hierarchical_fields} ); # we don't want hierarchical fields in an Excel export
    	$worksheet->write_string( 0, $col_id++, $col );
	}
	
	my $row_id = 1;

	# data...
	$opts{list}->map( sub {
		my( undef, undef, $user ) = @_;

		my $cols = $plugin->output_dataobj( $user, %$commons );
		return unless( scalar ( @$cols ) );

		my $col_id = 0;
		foreach my $col ( @$cols )
		{
			$worksheet->write_string( $row_id, $col_id++, $col );
		}
		$row_id++;
	} );

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

# Exports a single object / line. For CSV this must also includes the first four "common" fields.
sub output_dataobj
{
	my( $plugin, $dataobj, %commons ) = @_;

	my $session = $plugin->{session};

	return [] unless( $session->config( 'ref_enabled' ) );

	my $ref_fields = $plugin->ref_fields();

	my $objects = $plugin->get_related_objects( $dataobj );

	my $report = $plugin->get_report();
	my @rows;
	my $uoa_id = $plugin->get_current_uoa( $dataobj );
	return [] unless( defined $uoa_id );	# abort!
	
	my ( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa_id );
	return [] unless( defined $hefce_uoa_id );
	my $valid_ds = {};
	foreach my $dsid ( keys %$objects )
	{
		$valid_ds->{$dsid} = $session->dataset( $dsid );
	}

	my @common_fields;
        if( grep { $report eq $_ } @{$plugin->{session}->config( 'ref_2021_reports' )} )
        {
                @common_fields = ( "UKPRN", "UnitOfAssessment", "MultipleSubmission" );
        }
        else
        {
                @common_fields = ( "institution", "unitOfAssessment", "multipleSubmission", "action" );
        }

	# first we need to output the first 4 fields (the 'common' fields)
	foreach( @common_fields )
	{
		my $value;
		if( $_ eq 'unitOfAssessment' || $_ eq 'UnitOfAssessment' )	# get it from the ref_support_selection object
		{
			$value = $hefce_uoa_id;
		}
		elsif( $_ eq 'multipleSubmission' || $_ eq 'MultipleSubmission' ) 
		{ 
			$value = $is_multiple || ""; 
		}
		else
		{
			$value = $commons{$_};
		}
		if( EPrints::Utils::is_set( $value ) )
		{
			push @rows, $plugin->escape_value( $value );
		}
		else
		{
			push @rows, "";
		}

	}

	# don't print out empty rows so check that something's been done:
	my $done_any = 0;
	foreach my $hefce_field ( @{$plugin->ref_fields_order()} )
	{
		my $ep_field = $ref_fields->{$hefce_field};

		if( ref( $ep_field ) eq 'CODE' )
		{
			# a sub{} we need to run
			eval {
				my $value = &$ep_field( $plugin, $objects );
				if( EPrints::Utils::is_set( $value ) )
				{
					push @rows, $plugin->escape_value( $value );
					$done_any++ 
				}
				else
				{
					push @rows, "";
				}
			};
			if( $@ )
			{
				$session->log( "REF_CSV Runtime error: $@" );
			}

			next;
		}
		elsif( $ep_field !~ /^([a-z_]+)\.([a-z_\d]+)$/ )
		{
			# wrong format :-/
			push @rows, "";
			next;
		}

		# a straight mapping with an EPrints field
		my( $ds_id, $ep_fieldname ) = ( $1, $2 );
		my $ds = $valid_ds->{$ds_id};

		unless( defined $ds && $ds->has_field( $ep_fieldname ) )
		{
			# dataset or field doesn't exist
			push @rows, "";
			next;
		}

		my $value = $objects->{$ds_id}->value( $ep_fieldname );
		$done_any++ if( EPrints::Utils::is_set( $value ) );
		push @rows, $plugin->escape_value( $value );
	}

	return [] unless( $done_any );

	return \@rows;
}

sub escape_value
{
	my( $plugin, $value ) = @_;

	return "" unless( EPrints::Utils::is_set( $value ) );

	# if value is a pure number, then add ="$value" so that Excel stops the auto-formatting (it'd turn 123456 into 1.23e+6)
	#if( $value =~ /^\d+$/ )
	#{
	#	return "=\"$value\"";
	#}

	return $value;
}

1;
