package EPrints::Plugin::Export::REF_Support::REF_XML;

# HEFCE Generic Exporter to XML

use EPrints::Plugin::Export::REF_Support;
@ISA = ( "EPrints::Plugin::Export::REF_Support" );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "REF Support - XML";
	$self->{suffix} = ".xml";
	$self->{mimetype} = "text/xml";
        $self->{advertise} = $self->{enable} = EPrints::Utils::require_if_exists( "HTML::Entities" ) ? 1:0;
	$self->{is_hierarchical} = 1;

	return $self;
}

# sf2 / multipleSubmission is not in the XML template so that field is not currently exported (see http://www.ref.ac.uk/media/ref/content/subguide/3.ExampleImportFile.xml)
sub output_list
{
        my( $plugin, %opts ) = @_;
        my $list = $opts{list};
	my $session = $plugin->{session};
	my $fh = $opts{fh};
	my $skip_intro = $opts{skip_intro};
	my $institution = $plugin->escape_value( $session->config( 'ref', 'institution' ) || $session->phrase( 'archive_name' ) );
	my $action = $session->config( 'ref', 'action' ) || 'Update';

	# anytime we change to another UoA we need to regenerate a fragment of XML (<submission> etc...)
	my $current_uoa = undef;

	# the tags for opening/closing eg <outputs><output/></outputs> (ref2) or <staff><staffMember/></staff> (ref1abc)

	my( $main_tag, $secondary_tag, $tertiary_tag ) = $plugin->tags;
	
	unless( defined $main_tag && defined $secondary_tag )
	{
		$session->log( "REF_XML error - missing tags for report ".$plugin->get_report );
		return;		
	}

	# cater for a three tag structure, e.b. <staff><current><staffMember>
	my $item_tag = $secondary_tag;
	my $sub_tag;
	if( defined $tertiary_tag )
	{
		$item_tag = $tertiary_tag;
		$sub_tag = $secondary_tag;
	}

	if( !$skip_intro )
	{
print $fh <<HEADER;
<?xml version="1.0" encoding="utf-8"?>
<refData2021>
	<institution>$institution</institution>
	<submissions>
HEADER
	}

	$opts{list}->map( sub {
		my( undef, undef, $dataobj ) = @_;
		my $uoa = $plugin->get_current_uoa( $dataobj );
		return unless( defined $uoa );

		if( !defined $current_uoa || ( "$current_uoa" ne "$uoa" ) )
		{
			my( $hefce_uoa_id, $is_multiple ) = $plugin->parse_uoa( $uoa );
			return unless( defined $hefce_uoa_id );

			my $multiple = "";
			if( EPrints::Utils::is_set( $is_multiple ) )
			{
				$multiple = "<multipleSubmission>$is_multiple</multipleSubmission>";
			}

			if( defined $current_uoa )
			{
				print $fh <<CLOSING;
			</$main_tag>
		</submission>
CLOSING
			}

			print $fh <<OPENING;
		<submission>
			<unitOfAssessment>$hefce_uoa_id</unitOfAssessment>
			$multiple
			<$main_tag>

OPENING
			if( defined $sub_tag )
			{
				print $fh <<OPENING;
					<$sub_tag>
OPENING
			}
			$current_uoa = $uoa;
		}
		my $output = $plugin->output_dataobj( $dataobj );
		return unless( EPrints::Utils::is_set( $output ) );
		print $fh "<$item_tag>\n$output\n</$item_tag>\n";
	} );


	if( defined $current_uoa ) # i.e. have we output any records?
	{
		if( defined $sub_tag )
		{
			print $fh <<CLOSING;
				</$sub_tag>
CLOSING
		}
		print $fh <<CLOSING;
			</$main_tag>
		</submission>
CLOSING
	}

	if( !$skip_intro )
	{
print $fh <<FOOTER;
	</submissions>
</refData2021>
FOOTER
	}
}

sub output_intro
{
        my( $plugin, $fh ) = @_;
        my $session = $plugin->{session};

        my $institution = $plugin->escape_value( $session->config( 'ref', 'institution' ) || $session->phrase( 'archive_name' ) );

print $fh <<HEADER;
<?xml version="1.0" encoding="utf-8"?>
<ref2021Data>
        <institution>$institution</institution>
        <submissions>
HEADER
}

sub output_outtro
{
	my( $plugin, $fh ) = @_;
print $fh <<FOOTER;
        </submissions>
</ref2021Data>
FOOTER
}

sub tags
{
	my( $plugin ) = @_;

	my $report = $plugin->get_report;
	return () unless( defined $report );

	my $main;
	my $secondary;
	my $tertiary;
	if( $report =~ /^ref1[abc]$/ ) # 2014
	{
		$main = 'staff';
		$secondary = 'staffMember';
	}
	elsif( $report eq 'research_groups' )
	{
		$main = 'researchGroups';
                $secondary = 'group';
	}
	elsif( $report eq 'ref1_current_staff' )
	{
		#$main = 'staff';
		#$secondary = 'current';
		#$tertiary = 'staffMember';
		
		$main = 'current';
		$secondary = 'staffMember';

	}
	elsif( $report eq 'ref1_former_staff' ) # include former staff contracts
	{
		#$main = 'staff';
		#$secondary = 'former';
		#$tertiary = 'staffMember';
	
		$main = 'former';
		$secondary = 'staffMember';
	}
	elsif( $report eq 'ref1_former_staff_contracts')
	{
		$main = 'contracts';
                $secondary = 'contract';
	}
	elsif( $report eq 'ref2_staff_outputs' )
	{
		$main = 'staffOutputLinks';
                $secondary = 'staffOutputLink';
	}
	elsif( $report eq 'ref2' || $report eq 'ref2_research_outputs' )
	{
		$main = 'outputs';
		$secondary = 'output';
	}
	elsif( $report eq 'ref4' ) # used only by the complete submission report to extract content from the REF4_XML output
	{
		$main = 'environment';
		$secondary = 'researchDoctoralsAwarded';
	}
	elsif( $report eq 'research_groups' )
	{
		$main = 'researchGroups';
		$secondary = 'group';
	}

	return () unless( defined $main && defined $secondary );
	
	return( $main, $secondary, $tertiary );
}


# Note that undef/NULL values will not be included in the XML output
sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $session = $plugin->{session};

	my $ref_fields = $plugin->ref_fields();

	my $objects = $plugin->get_related_objects( $dataobj );
	return "" unless( EPrints::Utils::is_set( $objects ) );
	
	my $valid_ds = {};
	foreach my $dsid ( keys %$objects )
	{
		$valid_ds->{$dsid} = $session->dataset( $dsid );
	}

	my @values;
	my @catc_values;	# REF1c is a bit of a funny one
	foreach my $hefce_field ( @{$plugin->ref_fields_order()} )
	{
		my $ep_field = $ref_fields->{$hefce_field};

		if( ref( $ep_field ) eq 'CODE' )
		{
			eval {
				my( $value, $no_escape ) = &$ep_field( $plugin, $objects );
				next unless( EPrints::Utils::is_set( $value ) );
				if( !$no_escape )
				{
					$value = $plugin->escape_value( $value );
				}
				push @values, "<$hefce_field>".$value."</$hefce_field>";
			};
			if( $@ )
			{
				$session->log( "REF_XML: Runtime error: $@" );
			}

			next;
		}
		elsif( $ep_field =~ /^([a-z_]+)\.([a-z_]+)$/ )	# using an object field to extract data from
		{
			my( $ds_id, $ep_fieldname ) = ( $1, $2 );
			my $ds = $valid_ds->{$ds_id};

			next unless( defined $ds && $ds->has_field( $ep_fieldname ) );

			my $value = $objects->{$ds_id}->value( $ep_fieldname ) or next;
			
			# hacky you said?... well the Cat C fields need to have their own enclosure (I don't see the point but heh)
			if( $ep_field =~ /^ref_support_circ\.catc_/ )
			{
				push @catc_values, "<$hefce_field>".$plugin->escape_value( $value )."</$hefce_field>";
			}
			else
			{
				push @values, "<$hefce_field>".$plugin->escape_value( $value )."</$hefce_field>";
			}
		}
	}

	if( scalar( @catc_values ) )
	{
		push @values, "<categoryCCircumstances>\n".join( "\n", @catc_values )."</categoryCCircumstances>";
	}

	return join( "\n", @values );
}

sub escape_value
{
	my( $plugin, $value ) = @_;

	return undef unless( EPrints::Utils::is_set( $value ) );

	return HTML::Entities::encode_entities( $value, "<>&" );
}

1;
