package Genome::Model::Command::Annotate::AmlReportChunkerOld;

use strict;
use warnings;

use above "Genome";                

#use LSF::Job;
use MPSampleData::DBI;

class Genome::Model::Command::Annotate::AmlReportChunkerOld {
    is => 'Command',                       
    has => 
    [   
    dev => { type => 'String', doc => "?", is_optional => 0 },
    list1 => { type => 'String', doc => "?", is_optional => 0 },
    output => { type => 'String', doc => "?", is_optional => 0 },
    create_input => { type => 'Boolean', doc => "?", is_optional => 1 },
    ], 
};

sub help_brief 
{
    "chunks aml report"                 
}

sub help_synopsis
{
    return <<EOS
genome-model annotate aml-report-chunker --dev <db_name> --list1 <run_id> --output <output_file> --create_input
EOS
}

sub help_detail
{
    return <<EOS 
EOS
}

sub execute 
{   
    my $self = shift;

    # removed GetOptions, added getting options from 'self'
    # added option flag 'create_input' to replace checking for the ARGV[0]
    # changed dev to mean dw_dev, dw_rac, mysql_sd_test, mysql_sample_data
    my %options = 
    ( 
        'dev' => $self->dev,
        'list1' =>$self->list1,
        'out' =>$self->output,
        'create_input' =>$self->create_input,
    );
    my $quality=">=30";
=pod
    GetOptions( 

        'devel=s'       => \$options{'dev'},
        'list1=s'       => \$options{'list1'},
        'output=s'       => \$options{'out'},
    );
    $options{'list1'}=~tr/-/ / if(defined $options{'list1'});
=cut

    # overridden below
    #unless(defined($options{'dev'}) ) {
    #    croak "usage $0 --dev <database sample_data/sd_test..>";
    #}

# $X cannot have 'my($X)' or else it will close every time.

    # Changed the connection to use db aliases
    MPSampleData::DBI->connect($options{dev});
    my $X = MPSampleData::DBI->db_Main;
    my($sql_3);

    if ( grep { $options{dev} eq $_ } (qw/ sd_test sample_data /) )
    {
        # old connect:
        #my($Srv) = 'mysql2';
        #my($Uid) = "mgg_admin";
        #my($Pwd) = q{c@nc3r};
        #my($database) = "sample_data";
        #my($database) = $options{'dev'};

        #($X = UR::DBI->connect("DBI:mysql:$database:$Srv", $Uid, $Pwd))  or (die "fail to connect to datase \n");
        $sql_3 = <<EOS
select  chr.chromosome,rgg1.start,rgg1.end,
rgg1.allele1,rgg1.allele2,rgg1.allele1_type,rgg1.allele2_type,rgg1.num_reads1,rgg1.num_reads2
from  read_group_genotype rgg1 
join chromosome chr on chr.chrom_id=rgg1.chrom_id
where rgg1.read_group_id=(
select rg1.read_group_id from read_group rg1
where rg1.pp_id=( select pp1.pp_id from process_profile pp1
where pp1.concatenated_string_id=?))
EOS
;
    }
    elsif ( grep { $options{dev} eq $_ } (qw/ mg_dev mg_prod /) )
    {
        #($X = UR::DBI->connect("dbi:Oracle:dwdev", 'mguser', "mguser_dev", ))
        #   or (die "fail to connect to datase \n");
        $sql_3 = <<EOS
select  chr.chromosome_name,rgg1.start_,rgg1.end,
rgg1.allele1,rgg1.allele2,rgg1.allele1_type,rgg1.allele2_type,rgg1.num_reads1,rgg1.num_reads2
from  read_group_genotype rgg1 
join chromosome chr on chr.chrom_id=rgg1.chrom_id
where rgg1.read_group_id=(
select rg1.read_group_id from read_group rg1
where rg1.pp_id=( select pp1.pp_id from process_profile pp1
where pp1.concatenated_string_id=?))
EOS
;
    }
    else
    {
        die "invalid dev: $options{dev}\n";
    }


    print $options{'list1'},":query database\n";
    if($options{create_input}) {
        open(OUT,">$options{'out'}.dump") or die "can't open $options{'out'}.dump $!";
        my $sth;
        # commentted out the rm below, replacing with unlnking out file
        #`rm -rf ~xshi/dump/$options{'out'}.dump`;
        unlink $options{out} if -e $options{out};

        ($sth) = $X->prepare($sql_3) ;

        $sth->execute($options{'list1'}) ;
        while(my @re=$sth->fetchrow_array){
            print OUT join("\t", map { defined($_) ? $_ : 0 } @re),"\n";
#print @re,"\n";
        }
        close(OUT);
        $sth->finish;
        print "query finished\n";
    }
    $X->disconnect;

    # ending here, only getting the first 1000 for testing
    #return 1;
    
    `split $options{'out'}.dump $options{'out'}.dump_ -l 300000`;

#my @files=`ls $options{'out'}.dump_*`;
    my @files = <$options{'out'}.dump_[a-z][a-z]>;

    foreach my $file (@files){
        print "excute file $file\n";
        next;
        # TODO trigger jobs
        my $job = LSF::Job->submit(-oo => $file.'.bsub' ,"perl /gscuser/xshi/work/AML_SNP/aml_snp_report_paralle_module.pl --dev $options{'dev'} --file $file  ");
    }

    return 1;  
}

1;

