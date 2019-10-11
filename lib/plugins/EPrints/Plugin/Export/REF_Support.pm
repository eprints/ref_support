package EPrints::Plugin::Export::REF_Support;

# HEFCE REF Export - Abstract class
#
# generic class that can take REF1a/b/c and REF2 data and initialise the appropriate data structures prior to exporting to CSV, XML, ...

use EPrints::Plugin::Export;

@ISA = ( "EPrints::Plugin::Export" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF Support - Abstract Exporter class";
	$self->{accept} = [ 'report/ref1a', 'report/ref1b', 'report/ref1c', 'report/ref2', 'report/research_groups', 'report/ref1_current_staff', 'report/ref1_former_staff', 'report/ref1_former_staff_contracts', 'report/ref2_research_outputs', 'report/ref2_staff_outputs', 'report/submission' ];
	$self->{advertise} = 0;
	$self->{enable} = 1;
	$self->{visible} = 'staff';

	return $self;
}


sub initialise_fh
{
        my( $plugin, $fh ) = @_;

        binmode($fh, ":utf8" );

	# seems a bit hacky but that's the right place to send some extra HTTP headers - this one will tell the browser which files to save this report as.

	my $filename = ($plugin->{report}||'report')."_".EPrints::Time::iso_date().($plugin->{suffix}||".txt");

        EPrints::Apache::AnApache::header_out(
                      $plugin->{session}->get_request,
                      "Content-Disposition" => "attachment; filename=$filename"
        ); 
}

# Turns a REF Support (EPrints) subject id into:
# 1- the HEFCE code for the UoA
# 2- whether this is part of a multiple submission or not

# multiple submissions:
# ref20nna1 AND ref20nn_a1b exist -> 'A', 'B'
sub parse_uoa
{
        my( $plugin, $uoa_id ) = @_;

        my ( $hefce_uoa_id, $is_multiple );

	# multiple submission: on EPrints, those UoAs are encoded with an extra 'b' ('bis') at the end e.g. ref20nn_a1b for A1
        if( $uoa_id =~ /^ref20[0-9]{2}_(\w)(\d+)(b?)$/ )
        {
                $hefce_uoa_id = $2;
                # $is_multiple = EPrints::Utils::is_set( $3 );
		if( EPrints::Utils::is_set( $3 ) )
		{
			$is_multiple = 'B';
		}
		# it might still be a multiple submission ('A')
		if( !defined $is_multiple )
		{
			if( defined $plugin->{session}->dataset( 'subject' )->dataobj( $uoa_id."b" ) )
			{
				$is_multiple = 'A';
			}
		}
        }
        
        return( $hefce_uoa_id, $is_multiple );
}

# Extracts the UoA from different types of data objects. Exporters (XML, CSV...) need to know the UoA since it's a field for REF.
sub get_current_uoa
{
	my( $plugin, $object ) = @_;
	my $report = $plugin->get_report() or return undef;

	return undef unless( EPrints::Utils::is_set( $report ) );
	## technically, if we're viewing an old benchmark, a user UoA might not be set anymore :-( So we must get the info from somewhere else (and that is from one former ref_support_selection object)
	if( $report eq 'ref1_former_staff_contracts' ) # object is a circ
	{
		my $user = $object->user;
		my $uoa = $user->value( 'ref_support_uoa' );          
                if( defined $uoa )
                {
                        return $uoa;
                }
                if( defined $plugin->{benchmark} )      # && !defined $uoa
                {
                        # we might get it from one selection object
                        my $selections = $plugin->{benchmark}->user_selections( $user );
                        my $record = $selections->item( 0 );
                        if( defined $record )
                        {
                                return $record->current_uoa();
                        }
                }
	}
	elsif( $report =~ /^ref1/ )	# ref1a, ref1b, ref1c, ref1_current, etc.
	{
		# $object is EPrints::DataObj::User	
		my $uoa = $object->value( 'ref_support_uoa' );		
		if( defined $uoa )
		{
			return $uoa;
		}
		if( defined $plugin->{benchmark} )	# && !defined $uoa
		{
			# we might get it from one selection object
			my $selections = $plugin->{benchmark}->user_selections( $object );
			my $record = $selections->item( 0 );
			if( defined $record )
			{
				return $record->current_uoa();
			}
		}
	}
	elsif( $report =~ /^ref2/ || $report eq 'ref4' )
	{
		# $object is EPrints::DataObj::REF_Support_Selection
		return $object->current_uoa();
	}
	elsif( $report eq 'research_groups' )
	{
		return $object->get_value( "uoa" );
	}

	return undef;
}

# Which report are we currently exporting? values are set by the calling Screen::Report plugin and are: ref1a, ref1b, ref1c and ref2
sub get_report { shift->{report} }

# Generating a Report usually requires a few data objects (because data's stored in different places in EPrints).
sub get_related_objects
{
	my( $plugin, $dataobj ) = @_;

	my $report = $plugin->get_report();
	return {} unless( EPrints::Utils::is_set( $report ) && defined $dataobj );

	my $objects = {};
	my $session = $plugin->{session};
	
	if( $report eq 'ref1_former_staff_contracts' )
	{
		$objects = {
			ref_support_circ => $dataobj,
		};

		my $user = $dataobj->user;
                $objects->{user} = $user if( defined $user );
	}
	elsif( $report =~ /^ref1/ )	# ref1a, ref1b, ref1c, ref1_current_staff, etc.
	{
		# we receive a user object and need to give back a "ref circumstance" object
	        $objects = {
        	        user => $dataobj,
                	ref_support_circ => EPrints::DataObj::REF_Support_Circ->new_from_user( $session, $dataobj->get_id ),
	        };
	}
	elsif( $report =~ /^ref2/ )
	{
		# we receive a ref_support_selection object, and need to give back a user & eprint object
                $objects = {
                        ref_support_selection => $dataobj,
                        user => $session->dataset( 'user' )->dataobj( $dataobj->value( 'user_id' ) ),
                };
                my $eprint = $session->dataset( 'eprint' )->dataobj( $dataobj->value( 'eprint_id' ) );
                $objects->{eprint} = $eprint if( defined $eprint );
	}
	elsif( $report eq 'research_groups' )
	{
		$objects = {
			ref_support_rg => $dataobj,
		};
	}

	return $objects;
}

# Returns a list of (HEFCE/REF) fields in the order expected by HEFCE. The defaults are defined in the local configuration (zz_ref_reports.pl)
sub ref_fields_order
{
	my( $plugin ) = @_;

	return $plugin->{ref_fields_order} if( defined $plugin->{ref_fields_order} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{ref_fields_order} = $plugin->{session}->config( 'ref', $report, 'fields' );

	return $plugin->{ref_fields_order};
}

# Returns mappings between HEFCE/REF fields and EPrints' own fields. Look in zz_ref_reports.pl for more explanation on how this works.
sub ref_fields
{
	my( $plugin ) = @_;

	return $plugin->{ref_fields} if( defined $plugin->{ref_fields} );

	my $report = $plugin->get_report();
	return [] unless( defined $report );

	$plugin->{ref_fields} = $plugin->{session}->config( 'ref', $report, 'mappings' );

	return $plugin->{ref_fields};
}

1;
