
package Genome::Model::Command::List::Runs;

use strict;
use warnings;

use UR;
use GSC;
use Command; 
use Data::Dumper;
use Term::ANSIColor;
use Genome::Model::EqualColumnWidthTableizer;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "list all runs available for manipulation"
}

sub help_synopsis {
    return <<"EOS"
genome-model list runs
EOS
}

sub help_detail {
    return <<"EOS"
Lists all known runs
EOS
}

sub execute {
    my $self = shift;

    my @gerald_pses = @{ $self->_get_all_gerald_pses() };
    
    foreach my $pse (@gerald_pses)  {
        
        my $bustard_path = $self->_get_bustard_path_from_pse($pse);

        my @out = [
                   Term::ANSIColor::colored("Gerald Date:", 'red'),
                   Term::ANSIColor::colored($pse->date_scheduled, "cyan")
                   ];

        push @out, @{
                     $self->_get_sample_output_lines_by_plate_lanes_for_pse($pse)
                     };

        push @out, [
                    Term::ANSIColor::colored("Bustard Path", 'red'),
                    Term::ANSIColor::colored($bustard_path, "cyan")
                    ];
        
        Genome::Model::EqualColumnWidthTableizer->new->convert_table_to_equal_column_widths_in_place( \@out );
        
        print join( "\n",
                   
                   map { " @$_ " }
                        @out
                   
                   ), "\n\n\n";
    }

}

sub _get_bustard_path_from_pse{
    my ($self, $pse) = @_;
    
    my $gerald_path = GSC::PSEParam->get(
                                             param_name => 'gerald_directory',
                                             pse_id     => $pse
                                             )->param_value;
                                    
    my @paths = split /\//, $gerald_path;
    pop @paths;
    my $bustard_path = join "/", @paths;
    
    return $bustard_path;
}

sub _get_dna_to_solexa_load_lane_map_for_pse{
    my ($self, $pse) = @_;
    
    my $dna_his = GSC::PSE->dbh->selectall_arrayref(qq/select d.dna_name, dl.location_name from process_step_executions pse
                                                     join process_steps ps on ps.ps_id = pse.ps_ps_id
                                                     join (select distinct tpse.pse_id from tpp_pse tpse 
                                                           connect by prior tpse.prior_pse_id = tpse.pse_id
                                                           start with tpse.pse_id = ?) psehist on pse.pse_id = psehist.pse_id
                                                     join dna_pse dp on dp.pse_id = pse.pse_id
                                                     join dna d on d.dna_id = dp.dna_id
                                                     join dna_location dl on dl.dl_id = dp.dl_id
                                                     and ps.pro_process_to='generate clusters'
                                                     order by dl.location_order/, {}, $pse->pse_id);

    my %lane_mapping;
    
    foreach my $row (@$dna_his) {
        my ($dna, $loc) = @$row;
        my ($laneno) = $loc =~ /lane (\d+)/;
        
        $lane_mapping{$dna} .= $laneno;
    }
    
    return \%lane_mapping;
}

sub _get_sample_output_lines_by_plate_lanes_for_pse{
    my ($self, $pse) = @_;
    
    my @out;
    
    my %lane_mapping = %{ $self->_get_dna_to_solexa_load_lane_map_for_pse($pse) };

    foreach my $dna (keys %lane_mapping) {
        my $locs = $lane_mapping{$dna};
        
        my $lanes_text = '';
        unless($locs eq '12345678'){
            $lanes_text = ' in Lane';
            $lanes_text .= 's' if( length($locs) > 1 );
            $lanes_text .= ': ';
            $lanes_text .= $locs;
        }
        
        push @out, [
                    Term::ANSIColor::colored("Sample$lanes_text", 'red'),
                    Term::ANSIColor::colored($dna, "cyan")
                    ];
    }
        
    return \@out;
}

sub _get_all_gerald_pses{
    my $self = shift;
    
    #my $gerald_ps = GSC::ProcessStep->get(process_to=>'run alignment');
    
    GSC::PSE->get(1);

    my @gerald_pses = GSC::PSE->get(
                                    ps_id => [
                                              GSC::ProcessStep->get(
                                                    process_to => 'run alignment',
                                                    purpose => 'Solexa Analysis'
                                                ) or die
                                              ],
                                    pse_status => 'completed',
                                    pse_result => 'successful'
                                    ) or die;
    
    return \@gerald_pses;
}


1;

