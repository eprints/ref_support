#Applicable REF years
$c->{ref_support}->{years} = [qw( 2008 2009 2010 2011 2012 2013 2014 2015 2016 2017 2018 2019 )];

$c->{ref_support}->{income_years} = [qw( 2014 2015 2016 2017 2018 2019 )];


$c->{ref_support}->{first_year} = 2014;
$c->{ref_support}->{last_year} = 2020;

#The earliest year of the REF period - used by Screen/REF_Support/Listing.pm 'sub search_filters'
$c->{ref_support}->{earliest_year} = 2013;

#Prefix that all UOA ids start with - used by zz_ref_support_reports.pl 'sub ref2_support_cross_ref'
$c->{ref_support}->{uoa_prefix} = 'ref2021_';

#The 'top' id for the UOAs in the subject tree
$c->{ref_support}->{uoas} = 'ref2021_uoas';

#Use REF CC exclude field
$c->{ref_support}->{use_exclude} = 1;
