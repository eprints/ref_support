package EPrints::Plugin::Screen::REF_Support::Report::Complete_Submission;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

sub export
{
        my( $self ) = @_;

        my $export_plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $export_plugin;


	# different export plugins have different processes for building up the complete report
	if( $export_plugin->{mimetype} eq "text/xml" || $export_plugin->{mimetype} eq "application/json" )
	{
		# both the XML and JSON exports use the XML export plugin - if we're doing a JSON export, we can just cnvert it from XML to JSON later
		my $plugin = $self->{session}->plugin( "Export::REF_Support::REF_XML" );
		$self->xml_export( $export_plugin, $plugin );
	}
	elsif( $export_plugin->{mimetype} eq "application/vnd.ms-excel" )
	{
		$self->excel_export( $export_plugin );
	}
}

sub excel_export
{
	my( $self, $plugin ) = @_;

	my $session = $self->{session};
        my @uoas = @{ $self->{processor}->{uoas} || [] };

	my %reports = (
                "research_groups" => "Research_Groups",
                "ref1_current_staff" => "Current_Staff",
                "ref1_former_staff" => "Former_Staff",
		"ref1_former_staff_contracts" => "Former_Staff_Contracts",
                "ref2_research_outputs" => "Research_Outputs",
                "ref2_staff_outputs" => "Staff_Outputs",
        );

	# we need a worksheet for each report
	# to create worksheets we need a workbook
	
	#my $report_output;
        #open my $fh, '>', \$report_output or die "Can't open variable: $!";
        $plugin->initialise_fh( \*STDOUT );
	my $workbook = Spreadsheet::WriteExcel->new( \*STDOUT );
	$workbook->set_properties( utf8 => 1 );

	foreach my $report( keys %reports )
        {
		 # produce the report
		 my $report_plugin = "Screen::REF_Support::Report::" . $reports{$report};

		 $workbook = $self->run_report( $session, $workbook, $plugin, $report, $report_plugin, \@uoas );

		# reinitialise the export plugin
		$plugin->{ref_fields} = undef;
                $plugin->{ref_fields_order} = undef;
	}

	$workbook->close;
}

sub xml_export
{
	my( $self, $export_plugin, $plugin ) = @_;

	my $session = $self->{session};
	my @uoas = @{ $self->{processor}->{uoas} || [] };

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
		open my $fh, '>:encoding(UTF-8)', \$report_output or die "Can't open variable: $!";

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
		# not a priority right now...
 	}

	# now we have our final dom, comprised of all the other reports we just need to download it
        my $filename = ($export_plugin->{report}||'report')."_".EPrints::Time::iso_date().($export_plugin->{suffix}||".txt");
        EPrints::Apache::AnApache::header_out(
                $export_plugin->{session}->get_request,
                "Content-Disposition" => "attachment; filename=$filename"
        );
	
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
        return $report_plugin->export( $fh );
}

sub properties_from
{
	my( $self ) = @_;

	# will be used by the SUPER class:
	$self->{processor}->{report} = 'submission';

	$self->SUPER::properties_from;
}

sub render
{
        my( $self ) = @_;

        my $session = $self->{session};
        my @uoas = @{ $self->{processor}->{uoas} || [] };

	# set things up
        my $chunk = $session->make_doc_fragment;

        $chunk->appendChild( $session->html_phrase( "Plugin/Screen/REF_Support/Report:header",
                benchmark => $self->render_current_benchmark,
                export => $self->render_export_bar
        ) );

	# define our collection of sub reports
	my %reports = (
                "research_groups" => "Research_Groups",
                "ref1_current_staff" => "Current_Staff",
                "ref1_former_staff" => "Former_Staff",
                "ref1_former_staff_contracts" => "Former_Staff_Contracts",
                "ref2_research_outputs" => "Research_Outputs",
                "ref2_staff_outputs" => "Staff_Outputs",
        );

        foreach my $uoa ( @uoas )
        {
		# display the uoa title
		my $h3 = $chunk->appendChild( $session->make_element( 'h3', class => 'ep_ref_uoa_header' ) );
		$h3->appendChild( $uoa->render_description );

		# set up a report box
		my $div = $chunk->appendChild( $session->make_element( "div", class => "ep_ref_report_box" ) );

		# report box title
		my $title = $div->appendChild( $session->make_element( "div", class => "ep_ref_user_citation" ) );
		$title->appendChild( $session->make_text( "Reports Summary" ) );

		# set up a table for the summary
		my $table = $div->appendChild( $session->make_element( "table" ) );	

		# for each sub report provide some basi stats, i.e. how many records, are there any problems
		foreach my $report( keys %reports )
        	{			
			# prep the report plugin	
                	my $report_plugin = "Screen::REF_Support::Report::" . $reports{$report};
			my $plugin = $session->plugin( $report_plugin );
			$plugin->{processor}->{uoas} = [ $uoa ];
			$plugin->{processor}->{benchmark} = $self->current_benchmark;
			
			# display the relevant information for each report plugin
			my @table_cells;
			if( $report eq "research_groups" )
			{
				my $no_records = 0;
				my $no_problems = 0;

				# get the research groups and check for problems
				my $rgs = $plugin->research_groups;			
				if( EPrints::Utils::is_set( $rgs ) )
				{
					$no_records = $rgs->count;
				
					# check to see if there are any problems with them
					$rgs->map( sub {
						my( $session, undef, $rg ) = @_;
						my @problems = $plugin->validate_rg( $rg );
						$no_problems = $no_problems + scalar @problems;
					} );
				}
				
				push @table_cells, ( $session->make_text( $no_records ) );
				
				if( $no_problems > 0 )
				{
					my $warning_div = $session->make_element( "div", class => "ep_ref_report_user_problems" );
		                        $warning_div->appendChild( $self->html_phrase( "problems_reported" ) );
                        		push @table_cells, $warning_div;
				}
				
			}
			elsif( $report eq "ref1_current_staff" || $report eq "ref1_former_staff" )
			{
				my $no_records = 0;
                                my $no_problems = 0;
				
				# get the users and check for problems
				my $users = $plugin->users_by_uoa;
				if( EPrints::Utils::is_set( $users ) )
                                {
					# first get the number of records
					$no_records = $users->count;

					# now check for problems with any of them	
					# we need to borrow an export plugin to perform some of the validation checks
					my $export_plugin = $self->{session}->plugin( "Export::REF_Support" );
			        	$export_plugin->{report} = $report;
					$users->map( sub {
                                                my( $session, undef, $user ) = @_;
					        my $objects = $export_plugin->get_related_objects( $user );
						my @problems = $plugin->validate_user( $export_plugin, $objects );
						$no_problems = $no_problems + scalar @problems;
					} );
				}

				push @table_cells, ( $session->make_text( $no_records ) );
				if( $no_problems > 0 )
                                {
                                        my $warning_div = $session->make_element( "div", class => "ep_ref_report_user_problems" );
                                        $warning_div->appendChild( $self->html_phrase( "problems_reported" ) );
                                        push @table_cells, $warning_div;
                                }
			}
			elsif( $report eq "ref2_research_outputs" || $report eq "ref2_staff_outputs" )
			{
				my $no_records = 0;
                                my $no_problems = 0;

				# get the users and check for problems
                                my $selections = $plugin->get_selections;
                                if( EPrints::Utils::is_set( $selections ) )
                                {
					# first get the number of records
                                        $no_records = $selections->count;

					# now check for problems with any of them       
                                        # we need to borrow an export plugin to perform some of the validation checks
                                        my $export_plugin = $self->{session}->plugin( "Export::REF_Support" );
                                        $export_plugin->{report} = $report;
                                        $selections->map( sub {
                                                my( $session, undef, $selection ) = @_;
                                                my $objects = $export_plugin->get_related_objects( $selection );
                                                my $problems_object = $plugin->validate_selection( $export_plugin, $objects );
						$no_problems = $no_problems + 1 if defined $problems_object->{problem};
                                        } );
				}
				push @table_cells, ( $session->make_text( $no_records ) );
                                if( $no_problems > 0 )
                                {
                                        my $warning_div = $session->make_element( "div", class => "ep_ref_report_user_problems" );
                                        $warning_div->appendChild( $self->html_phrase( "problems_reported" ) );
                                        push @table_cells, $warning_div;
                                }
			}
			elsif( $report eq "ref1_former_staff_contracts" )
			{
				my $no_records = 0;
                                my $no_problems = 0;

                                # get the contracts and check for problems
                                my $contracts = $plugin->get_contracts;
                                if( EPrints::Utils::is_set( $contracts ) )
                                {
                                        # first get the number of records
                                        $no_records = $contracts->count;

                                        # now check for problems with any of them       
                                        # we need to borrow an export plugin to perform some of the validation checks
                                        my $export_plugin = $self->{session}->plugin( "Export::REF_Support" );
                                        $export_plugin->{report} = $report;
                                        $contracts->map( sub {
                                                my( $session, undef, $contract ) = @_;
                                                my $objects = $export_plugin->get_related_objects( $contract );
                                                my $problems_object = $plugin->validate_circ( $export_plugin, $objects );
                                                $no_problems = $no_problems + 1 if defined $problems_object->{problem};
                                        } );
                                }
                                push @table_cells, ( $session->make_text( $no_records ) );
                                if( $no_problems > 0 )
                                {
                                        my $warning_div = $session->make_element( "div", class => "ep_ref_report_user_problems" );
                                        $warning_div->appendChild( $self->html_phrase( "problems_reported" ) );
                                        push @table_cells, $warning_div;
                                }
			}
			$table->appendChild( $session->render_row( $plugin->render_title, @table_cells ) );
		}
	}

	return $chunk;
}

1;
