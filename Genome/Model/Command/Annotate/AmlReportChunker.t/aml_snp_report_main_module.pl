#!/gsc/bin/perl


use strict;
use warnings;

use Getopt::Long;
use Carp;
use DBI;
use LSF::Job;


my %options = ( 
                'dev'         => undef,
		'list1'		=>undef,
		'output' =>undef,
 	     );
my $quality=">=30";
GetOptions( 
	  
           'devel=s'       => \$options{'dev'},
	   'list1=s'       => \$options{'list1'},
	   'output=s'       => \$options{'out'},
	);
$options{'list1'}=~tr/-/ / if(defined $options{'list1'});

unless(defined($options{'dev'}) ) {
    croak "usage $0 --dev <database sample_data/sd_test..>";
}


my($Srv) = 'mysql2';
my($Uid) = "mgg_admin";
my($Pwd) = q{c@nc3r};
my($database) = "sample_data";
#my($database) = $options{'dev'};
 
my($X);
# $X cannot have 'my($X)' or else it will close every time.
($X = DBI->connect("DBI:mysql:$database:$Srv", $Uid, $Pwd))  or (die "fail to connect to datase \n");





my $sql_3 = <<EOS
select  chr.chromosome,rgg1.start,rgg1.end,
rgg1.allele1,rgg1.allele2,rgg1.allele1_type,rgg1.allele2_type,rgg1.num_reads1,rgg1.num_reads2,rgg1.rgg_id
from  read_group_genotype rgg1 
join chromosome chr on chr.chrom_id=rgg1.chrom_id
where rgg1.read_group_id=(
select rg1.read_group_id from read_group rg1
where rg1.pp_id=( select pp1.pp_id from process_profile pp1
where pp1.concatenated_string_id=?))
EOS
;

print $options{'list1'},":query database\n";
unless($ARGV[0]) {
open(OUT,">$options{'out'}.dump") or die "can't open $options{'out'}.dump $!";
my $sth;
`rm -rf ~dlarson/dump/$options{'out'}.dump`;

($sth) = $X->prepare($sql_3) ;

$sth->execute($options{'list1'}) ;
while(my @re=$sth->fetchrow_array){
 print OUT join("\t",@re),"\n";
#print @re,"\n";
}
close(OUT);
$sth->finish;
print "query finished\n";
}
$X->disconnect;
 
 `split $options{'out'}.dump $options{'out'}.dump_ -l 110000`;

#my @files=`ls $options{'out'}.dump_*`;
my @files = <$options{'out'}.dump_[a-z][a-z]>;

foreach my $file (@files){
print "excute file $file\n";
  my $job = LSF::Job->submit(-oo => $file.'.bsub' ,"perl /gscuser/dlarson/analysis/xshi_variant_annotation/aml_snp_report_paralle_module.pl --dev $options{'dev'} --file $file  ");
}

#$HeadURL$
#$Id$
