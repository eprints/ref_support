package EPrints::Plugin::Screen::REF_Support::Report::Complete_Submission;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

sub export
{
        my( $self ) = @_;

        my $export_plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $export_plugin;

	my $session = $self->{session};
	my @uoas = @{ $self->{processor}->{uoas} || [] };
	
	# the complete submission report only ever uses the XML plugin... so let's enforce that
	my $plugin = $session->plugin( "Export::REF_Support::REF_XML" );

	my %reports = (
		"research_groups" => "Research_Groups",
		"ref1_current_staff" => "Current_Staff",
		"ref1_former_staff" => "Former_Staff",
		"ref2_research_outputs" => "Research_Outputs",
		"ref2_staff_outputs" => "Staff_Outputs",
	);

	my $export_reports = {};

	foreach my $report( keys %reports )
	{
		# set up a filehandle
		my $report_output;
		open my $fh, '>', \$report_output or die "Can't open variable: $!";

		# produce the report
		my $report_plugin = "Screen::REF_Support::Report::" . $reports{$report};

		$self->run_report( $session, $fh, $plugin, $report, $report_plugin, \@uoas );

		close $fh;
		$export_reports->{$report} = $report_output;

		# reinitialise the export plugin
		$plugin->{ref_fields} = undef;
       		$plugin->{ref_fields_order} = undef;
	}

	# now we have all the reports, create a master report merging them all together
	# we'll use the research groups report to get us started
	my $master_dom = XML::LibXML->load_xml(string => $export_reports->{research_groups});

	# for each report extract the contents for each submission
	foreach my $report( keys %reports )
	{
		next if $report eq "research_groups"; # we're using this report as our starting point, so no need to extract anything from it
		my $dom = XML::LibXML->load_xml(string => $export_reports->{$report});

		# get tag for the content we'll want to extract
		$plugin->{report} = $report;
		my( $main_tag, $secondary_tag, $tertiary_tag ) = $plugin->tags;
		foreach my $uoa ( $dom->findnodes( '//unitOfAssessment' ) )
		{
			# get the uoa id (used to place this section in the correct section for the master document) and the submission element
			my $uoa_id = $uoa->textContent;
			my $submission = $uoa->parentNode;

			# now retrive the content we after from the submission
			my $main = @{$submission->findnodes( $main_tag )}[0];
			
			# finally, append this to the correct unit of assessment in the master document
			my $seen = 0;
			foreach my $master_uoa( $master_dom->findnodes( '//unitOfAssessment' ) )
			{
				if( $master_uoa->textContent eq $uoa_id )
				{
					my $master_submission = $master_uoa->parentNode;

					if( $report eq "ref1_current_staff" || $report eq "ref1_former_staff" ) # these sections need to go in their own staff section
					{
						my $staff = @{$master_submission->findnodes( 'staff' )}[0];
						if( !defined $staff )
						{
							$staff = $master_submission->addNewChild( undef, 'staff' );
						}
						$staff->appendChild( $main );
					}
					else
					{
						$master_submission->appendChild( $main );
					}
					$seen = 1;
					last; # we're done here
				}
			}
			if( !$seen )
			{
				#print STDERR "master......$master_dom\n";
				my $submissions = @{$master_dom->findnodes( "//submissions" )}[0];
				$submissions->appendChild( $submission );
			}
		}
	}

	# we now have a final XML dom comprised of all the other reports
	# but what if we wanted a different type of export...?
	my $final_string;
	my $export = $export_plugin->{id};
	if( $export eq "Export::REF_Support::REF_XML" )
	{
		$final_string = $master_dom->toString;
	}
	elsif( $export eq "Export::REF_Support::REF_JSON" )
	{
		use XML::XML2JSON;
		my $XML2JSON = XML::XML2JSON->new();
		$final_string = $XML2JSON->convert($master_dom->toString);
 	}

	# now we have our final dom, comprised of all the other reports
	$export_plugin->initialise_fh( \*STDOUT );
	print $final_string;
}


        # call initialise_fh if we want to download
        # $plugin->initialise_fh( \*STDOUT );
        # $plugin->output_list(
        #        list => $rg_list,
        #        fh => \*STDOUT,
        #        benchmark => $self->{processor}->{benchmark},
        # );

        # but if we want to local file (say if we want to then submit to the API!) then we need to not call initialise_fh and instead give output_list a $fh
        # my $filename = '/tmp/submission.xml';
        # open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
        # $plugin->output_list(
        #        list => $rg_list,
        #        fh => $fh,
        #        benchmark => $self->{processor}->{benchmark},
        # );
#}

sub run_report
{
	my( $self, $session, $fh, $export_plugin, $report, $report_plugin, $uoas ) = @_;

	# get the report plugin
        $report_plugin = $session->plugin( $report_plugin );

        # prep the export plugin
        $export_plugin->{report} = $report;

        # prep the screen plugin
        $report_plugin->{processor}->{plugin} = $export_plugin;
        $report_plugin->{processor}->{report} = $report;
        $report_plugin->{processor}->{benchmark} = $self->current_benchmark;
        $report_plugin->{processor}->{uoas} = $uoas;

        # run the export
        $report_plugin->export( $fh );
}

sub properties_from
{
	my( $self ) = @_;

	# will be used by the SUPER class:
	$self->{processor}->{report} = 'submission';

	$self->SUPER::properties_from;
}

1;
