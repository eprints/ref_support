package EPrints::Plugin::Screen::REF_Support::Report::Complete_Submission;

use EPrints::Plugin::Screen::REF_Support::Report;
@ISA = ( 'EPrints::Plugin::Screen::REF_Support::Report' );

use strict;

sub export
{
        my( $self ) = @_;

        my $plugin = $self->{processor}->{plugin};
        return $self->SUPER::export if !defined $plugin;

	my $session = $self->{session};
	my @uoas = @{ $self->{processor}->{uoas} || [] };
	
	# for each uoa we need to loop through the various report plugins and call output list with a different set of options each time
	# get it's research groups
	# get staff
	# and get research outputs

	#my %reports = (
	 #       "research_groups" => "Research_Groups",
	#	"ref1_current_staff" => "",
	#	"ref1_former_staff" => ""
	#);

	my $skip_intro = 1;

	my $export_outputs;
	open my $fh, '>', \$export_outputs or die "Can't open variable: $!";

	# run export intro
	$plugin->output_intro( $fh );

	my $report_plugin; 
	my $export_plugin;
	my $report;

	foreach my $uoa ( @uoas )
	{
		# research groups
		$report_plugin = "Screen::REF_Support::Report::" . "Research_Groups";
		$export_plugin = $plugin;
		$report = "research_groups";
		$self->run_report( $session, $fh, $export_plugin, $report, $report_plugin, $uoa );

		# reinitialise export plugin	
		$export_plugin->{ref_fields} = undef;
        	$export_plugin->{ref_fields_order} = undef;

		# current_staff
		$report_plugin = "Screen::REF_Support::Report::" . "Current_Staff";
		$export_plugin = $plugin;
		$report = "ref1_current_staff";
		$self->run_report( $session, $fh, $export_plugin, $report, $report_plugin, $uoa );
	}

	$plugin->output_outtro( $fh );

	close $fh;
	print STDERR "export_outputs 2.....$export_outputs\n";

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
}

sub run_report
{
	my( $self, $session, $fh, $export_plugin, $report, $report_plugin, $uoa ) = @_;

	my @report_uoas;
	push @report_uoas, $uoa;

	# get the research groups plugin
        $report_plugin = $session->plugin( $report_plugin );

        # prep the export plugin
        $export_plugin->{report} = $report;

        # prep the screen plugin
        $report_plugin->{processor}->{plugin} = $export_plugin;
        $report_plugin->{processor}->{report} = $report;
        $report_plugin->{processor}->{benchmark} = $self->current_benchmark;
        $report_plugin->{processor}->{uoas} = \@report_uoas;

        # run the export
	my $skip_intro = 1;
        $report_plugin->export( $fh, $skip_intro );
}

sub properties_from
{
	my( $self ) = @_;

	# will be used by the SUPER class:
	$self->{processor}->{report} = 'submission';

	$self->SUPER::properties_from;
}

1;
