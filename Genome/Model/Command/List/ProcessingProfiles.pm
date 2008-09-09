
package Genome::Model::Command::List::ProcessingProfiles;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "list all processing profiles available for manipulation"
}

sub help_synopsis {
    return <<"EOS"
genome-model list processing-profiles
EOS
}

sub help_detail {
    return <<"EOS"
Lists all known processing profiles.
EOS
}

sub execute {
    my $self = shift;
    my @processing_profiles = Genome::ProcessingProfile->get();
    
    for my $profile (@processing_profiles) {
        print $profile->pretty_print_text;
    }
}


1;

