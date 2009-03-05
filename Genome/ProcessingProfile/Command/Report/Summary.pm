package Genome::ProcessingProfile::Command::Report::Summary;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::ProcessingProfile::Command::Report::Summary {
    is => 'Command',
    has_constant => [
        sql => { 
            value => 'select * from (select p.id,p.type_name,p.name,count(distinct m.subject_name) subjects, count(distinct m.genome_model_id) models,count(distinct b.build_id) builds from mg.processing_profile p left join mg.genome_model m on m.processing_profile_id = p.id left join mg.genome_model_build b on b.model_id = m.genome_model_id group by p.id,p.type_name,p.name) x order by type_name, builds, models, subjects',
        },
    ]
};

sub execute {
    my $self = shift;
    my $sql = $self->sql;
    my $dbh = Genome::DataSource::GMSchema->get_default_handle();
    UR::Report->generate( sql => [$sql], dbh => $dbh); 
    # my $ch = IO::File->new("| sqlrun - --instance warehouse");
    # $ch->print($sql);
    # $ch->close;
    return 1;
}

1;

