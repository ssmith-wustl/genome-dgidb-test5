
package Genome::Model::Command::List::Runs;

use strict;
use warnings;

use UR;
use GSC;
use Command; 
use Data::Dumper;
use Term::ANSIColor;

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

    #my $gerald_ps = GSC::ProcessStep->get(process_to=>'run alignment');
    
    GSC::PSE->get(1);


    my @gerald_pses = GSC::PSE->get(sql=>qq/select pse.* from process_step_executions pse
                                    join process_steps ps on ps.ps_id = pse.ps_ps_id 
                                    where ps.pro_process_to='run alignment' and ps.purpose='Solexa Analysis'
                                    and pse.psesta_pse_status='completed' and pse.pr_pse_result='successful'/);
    
    foreach my $pse (@gerald_pses)  {
        my $gerald_path = GSC::PSEParam->get(param_name=>'gerald_directory',
                                             pse_id=>$pse)->param_value;
                                    
        my @paths = split /\//, $gerald_path;
        pop @paths;
        
        my $bustard_path = join "/", @paths;



        my @out = [Term::ANSIColor::colored("Gerald Date:", 'red'),
                   Term::ANSIColor::colored($pse->date_scheduled, "cyan")];

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
        
        


        foreach my $dna (keys %lane_mapping) {
            my $locs = $lane_mapping{$dna};
            push @out, [
                        Term::ANSIColor::colored("Lane(s): $locs", 'red'),
                        Term::ANSIColor::colored($dna, "cyan")
                        ];
        }

        push @out, [
                    Term::ANSIColor::colored("Bustard Path", 'red'),
                    Term::ANSIColor::colored($bustard_path, "cyan")
                    ];
        

        
        _make_table_columns_equal_width(\@out);

        my $pout;
        $pout .= join("\n", map { " @$_ " } @out);
        
        print $pout, "\n\n\n";


    }

}

sub _make_table_columns_equal_width {
    my $arrayref = shift;
    my @max_length;
    for my $row (@$arrayref) {
        for my $col_num (0..$#$row) {
            $max_length[$col_num] ||= 0;
            if ($max_length[$col_num] < length($row->[$col_num])) {                
                $max_length[$col_num] = length($row->[$col_num]);
            }
        }
    }
    for my $row (@$arrayref) {
        for my $col_num (0..$#$row) {
            $row->[$col_num] .= ' ' x ($max_length[$col_num] - length($row->[$col_num]) + 1);
        }
    }    
}


1;

