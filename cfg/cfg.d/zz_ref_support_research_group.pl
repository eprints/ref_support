#
## EPrints Services - REF Support
##
## Version: 2.0

$c->{plugins}{"Screen::REF_Support::Research_Group::New"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Research_Group::Edit"}{params}{disable} = 0;
$c->{plugins}{"Screen::REF_Support::Research_Group::Destroy"}{params}{disable} = 0;

{
no warnings;

package EPrints::DataObj::REF_Support_Research_Group;

@EPrints::DataObj::REF_Support_Research_Group::ISA = qw( EPrints::DataObj );

sub get_dataset_id { "ref_support_rg" }

sub get_url { shift->uri }

sub get_defaults
{
        my( $class, $session, $data, $dataset ) = @_;

        $data = $class->SUPER::get_defaults( @_[1..$#_] );

        return $data;
}

sub get_control_url { $_[0]->{session}->config( "userhome" )."?screen=REF_Support::EditResearchGroup&rgid=".$_[0]->get_id }

=item $list = EPrints::DataObj::REF_Support_Research_Group::search_by_uoa( $session, $uoa )

Returns the Research Groups belonging to the uoa

=cut
sub search_by_uoa
{
        my( $class, $session, $uoa ) = @_;

        return $session->dataset( $class->get_dataset_id )->search(
                filters => [
                        { meta_fields => [qw( uoa )], value => $uoa->id, match => "EX", },
                ],
        );
}

=item $list = EPrints::DataObj::REF_Support_Research_Group::search_by_uoa_and_code( $session, $uoa, $code )

Returns a Research Group by uoa nd code

=cut
sub search_by_uoa_and_code
{
        my( $session, $uoa, $code ) = @_;

        return $session->dataset( 'ref_support_rg' )->search(
                filters => [
                        { meta_fields => [qw( uoa )], value => $uoa, match => "EX", },
			{ meta_fields => [qw( code )], value => $code, match => "EX", },
                ],
        );
}


} # end of package

# Research Group Dataset definition
$c->{datasets}->{ref_support_rg} = {
        class => "EPrints::DataObj::REF_Support_Research_Group",
        sqlname => "ref_support_rg",
        name => "ref_support_rg",
        columns => [qw( rgid name code )],
        index => 1,
        import => 1,
};

$c->{fields}->{ref_support_rg} = [] if !defined $c->{fields}->{ref_support_rg};
unshift @{$c->{fields}->{ref_support_rg}}, (
                { name => "rgid", type=>"counter", required=>1, can_clone=>0,
                        sql_counter=>"rgid" },

                { name=>"uoa", type=>"subject",
                        top=>$c->{ref_support}->{uoas}, required=>1 },

                { name=>"code", type=>"text",
                        maxlength=>1, required=>1 },

                { name=>"name", type=>"text",
			maxlength=>64, required=>1 },
);

push @{$c->{user_roles}->{admin}}, qw{
        +ref_support_rg/details
        +ref_support_rg/edit
        +ref_support_rg/view
        +ref_support_rg/create_new
        +ref_support_rg/delete
};
