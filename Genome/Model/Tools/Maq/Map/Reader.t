#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";                         # >above< ensures YOUR copy is used during development
use Genome::InlineConfig;
use Genome::Model::Tools::Maq::Map::Reader;

#use Test::More tests => 20;
use Test::More skip_all => 'disabled until intermittent failure issue is resolved'; 
use Storable;
our $cflags;
our $libs;
BEGIN
{
    $libs = '-L/var/chroot/etch-ia32/usr/lib -L/usr/lib -L/lib ';        
};

use Inline 'C' => 'Config' => (
            CC => '/gscmnt/936/info/jschindl/gcc32/gcc',
            DIRECTORY => Genome::InlineConfig::DIRECTORY(), 
            INC => '-I/gscmnt/936/info/jschindl/inline_c_deps -I/gsc/pkg/bio/maq/zlib/include',
            CCFLAGS => '-D_FILE_OFFSET_BITS=64 -m32 ',
            LD => '/gscmnt/936/info/jschindl/gcc32/ld',
            LIBS => '-L/gscmnt/936/info/jschindl/inline_c_deps -L/gsc/pkg/bio/maq/zlib/lib -lz -lmaq '.$libs,
            NAME => __PACKAGE__
            );

my $indata = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq-Map';
my $stored_data = retrieve("$indata/test.store");
my $mi;
ok($mi = Genome::Model::Tools::Maq::Map::Reader->new(file_name => "$indata/2.map"), 'create reader from object with filename');
ok($mi = Genome::Model::Tools::Maq::Map::Reader->new,'create reader from class');
ok(do{ eval {$mi->read_header()}; $@ ? 1 : 0; },'Tested read_header error condition');
ok(bless({},'Genome::Model::Tools::Maq::Map::Reader')->new,'create reader from object');
ok(do {
    eval {
        Genome::Model::Tools::Maq::Map::Reader::new;
    };
    $@ ? 1 : 0;
},'reader creation failed gracefully');


ok($mi->open("$indata/2.map"),'open 2.map');

my $header;
ok($header = $mi->read_header,'read header');

my @records;

while(my $record = $mi->get_next)
{
    push @records, $record;
}
is_deeply($header, $stored_data->{header},'header is correct');
is_deeply(\@records, $stored_data->{records},'records are correct');

ok($mi->reset, 'reset 2.map');
@records = ();
ok(!$mi->do(\&test),'call do function');
is_deeply(\@records, $stored_data->{records},'records are correct');

ok($mi->reset, 'reset 2.map');
@records = ();
ok(!$mi->do('test'),'call do function');
is_deeply(\@records, $stored_data->{records},'records are correct');

ok($mi->reset, 'reset 2.map');
@records = ();
open_map("$indata/2.map");

ok(!$mi->do('do_func_c'),'call do function');
ok(get_test_status(),'do_func_c called successfully');
close_map();
ok(!$mi->close, 'close 2.map');

my ($type, $ref) = $mi->resolve_func_type(undef,undef);
ok(!$type,'test error condition');

sub test
{
    my ($record) = @_;
    push @records,$record;
}

use Inline C => <<'END_C';
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))

gzFile fp;
void open_map(char *mapfilename)
{
   fp=NULL;
   fp=gzopen(mapfilename,"r");
   maqmap_t  *mm = maqmap_read_header(fp);

}
int test_status = 1;
void close_map()
{
    gzclose(fp);

}
void do_func_c(maqmap1_t *mm)
{
    maqmap1_t temp;
    get_record(fp,&temp);
    if(memcmp(&temp,mm,sizeof(temp))) test_status = 0;
}

int get_test_status()
{
    return test_status;
}
END_C
