package EPrints::Plugin::Export::REF_Support::REF_CSV;

# HEFCE Generic Exporter to CSV 

use EPrints::Plugin::Export::REF_Support;
@ISA = ( "EPrints::Plugin::Export::REF_Support" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF Support - CSV";
	$self->{suffix} = ".csv";
	$self->{mimetype} = "text/plain; charset=utf-8";
	$self->{advertise} = 1;
	$self->{accept} = [ 'report/ref1a', 'report/ref1b', 'report/ref1c', 'report/ref2', 'report/research_groups', 'report/ref1_current_staff', 'report/ref1_former_staff', 'report/ref1_former_staff_contracts', 'report/ref2_research_outputs', 'report/ref2_staff_outputs', 'report/ref4_doctoral_degrees' ];
	$self->{is_hierarchical} = 0;

	return $self;
}

# Main method - called by the appropriate Screen::Report plugin
sub output_list
{
        my( $plugin, %opts ) = @_;
       
	# the appropriate REF::Report::{report_id} plugin will build up the list: 
	my $session = $plugin->{session};
	$plugin->{benchmark} = $opts{benchmark};

	my $institution = $session->config( 'ref', 'institution' ) || $session->phrase( 'archive_name' );
	my $action = $session->config( 'ref', 'action' ) || 'Update';

	# CSV header / field list
	my $report = $plugin->get_report();
	my $commons = {};
	if( grep { $report eq $_ } @{$plugin->{session}->config( 'ref_2021_reports' )} )
	{
		print "ukprn,unitOfAssessment,multipleSubmission,".join( ",", @{$plugin->ref_fields_order()} )."\n";

		# common fields/values
		$commons = {
			ukprn => $institution,
		};
	}	
	else
	{
		print "institution,unitOfAssessment,multipleSubmission,action,".join( ",", @{$plugin->ref_fields_order()} )."\n";

		# common fields/values
		$commons = {
			institution => $institution,
			action => $action,
		};
	}
	$opts{list}->map( sub {
		my( undef, undef, $user ) = @_;
		my $output = $plugin->output_dataobj( $user, %$commons );
		return unless( defined $output );
		print "$output\n";
	} );
}

# Exports a single object / line. For CSV this must also includes the first four "common" fields.
sub output_dataobj
{
	my( $plugin, $dataobj, %commons ) = @_;
	my $session = $plugin->{session};	
	return "" unless( $session->config( 'ref_enabled' ) );
	
	my $ref_fields = $plugin->ref_fields();

	my $objects = $plugin->get_related_objects( $dataobj );

	my $report = $plugin->get_report();

	my @values;
	my $uoa_id;
	my $hefce_uoa_id;
	my $is_multiple;

	$uoa_id = $plugin->get_current_uoa( $dataobj );
	return "" unless( defined $uoa_id );	# abort!
	
	( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa_id );
	return "" unless( defined $hefce_uoa_id );	
	
	my $valid_ds = {};
	foreach my $dsid ( keys %$objects )
	{
		$valid_ds->{$dsid} = $session->dataset( $dsid );
	}

	my @common_fields;
	if( grep { $report eq $_ } @{$plugin->{session}->config( 'ref_2021_reports' )} )
        {
		@common_fields = ( "ukprn", "unitOfAssessment", "multipleSubmission" );
	}
	else
	{
		@common_fields = ( "institution", "unitOfAssessment", "multipleSubmission", "action" );
	}
	
	# first we need to output the first 4 fields (the 'common' fields)
	foreach( @common_fields )
	{
		my $value;
		if( $_ eq 'unitOfAssessment' )	# get it from the ref_support_selection object
		{
			$value = $hefce_uoa_id;
		}
		elsif( $_ eq 'multipleSubmission' ) 
		{ 
			$value = $is_multiple || ""; 
		}
		else
		{
			$value = $commons{$_};
		}
		if( EPrints::Utils::is_set( $value ) )
		{
			push @values, $plugin->escape_value( $value );
		}
		else
		{
			push @values, "";
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
					push @values, $plugin->escape_value( $value );
					$done_any++ 
				}
				else
				{
					push @values, "";
				}
			};
			if( $@ )
			{
				$session->log( "REF_CSV Runtime error: $@" );
			}

			next;
		}
		elsif( $ep_field !~ /^([a-z_]+)\.([a-z_]+)$/ )
		{
			# wrong format :-/
			push @values, "";
			next;
		}

		# a straight mapping with an EPrints field
		my( $ds_id, $ep_fieldname ) = ( $1, $2 );
		my $ds = $valid_ds->{$ds_id};
		unless( defined $ds && $ds->has_field( $ep_fieldname ) )
		{
			# dataset or field doesn't exist
			push @values, "";
			next;
		}
		
		my $value = $objects->{$ds_id}->value( $ep_fieldname );
		$done_any++ if( EPrints::Utils::is_set( $value ) );
		push @values, $plugin->escape_value( $value );
	}
	return undef unless( $done_any );

	return join( ",", @values );
}

sub escape_value
{
	my( $plugin, $value ) = @_;

	return '""' unless( defined EPrints::Utils::is_set( $value ) );

	# strips any kind of double-quotes:
	$value =~ s/\x93|\x94|"/'/g;
	# and control-characters
	$value =~ s/\n|\r|\t//g;

	# if value is a pure number, then add ="$value" so that Excel stops the auto-formatting (it'd turn 123456 into 1.23e+6)
	if( $value =~ /^\d+$/ )
	{
		return "=\"$value\"";
	}

	# only escapes values with spaces and commas
	if( $value =~ /,| / )
	{
		return "\"$value\"";
	}

	return $value;
}


1;
