# Which list to use?
denylist_samples.txt is currently more complete, except for the ones that lack a biosample accession entirely.

# Why Deny?

## not on google mirror, seem to have no data, do not have a biosample accession
ERR3256208
ERR1274706
ERR1873513
ERR760606
ERR760780
ERR760898
ERR845308
ERR181439
ERR181441

## appear in list Z, but aren't TB (biosample: SRS000422 but also can be reached via 307 which is how it's in list Z)
SRR001703
SRR001704
SRR001705

## fails fasterq-dump3.0.0 (biosample: SRS544089)
SRR1180610
SRR1180764

## known to be TN-Seq (by sample, since there's so many of them)
SRS15530894
SRS15530895
SAMN12913102
SAMN12913101
SAMN12913100
SAMN12913099
SAMN12913098
SAMN12913097
SAMN12913096
SAMN12913095
SAMN12913106
SAMN12913105
SAMN12913104
SAMN12913103
SAMN12913094
SAMN12913093
SAMN15337427
SAMN15337427
SAMN15337427
SAMN15337427
SAMN15337427
SAMN15337427
SAMN15567639
SAMN15567638
SAMN15567637
SAMN15567636
SAMN15567683
SAMN15567682
SAMN15567681
SAMN15567680
SAMN15567679
SAMN15567678
SAMN15567677
SAMN15567676
SAMN15567675
SAMN15567674
SAMN15567673
SAMN15567672
SAMN15567671
SAMN15567670
SAMN15567669
SAMN15567668
SAMN15567667
SAMN15567666
SAMN15567665
SAMN15567664
SAMN15567689
SAMN15567688
SAMN15567687
SAMN15567686
SAMN15567685
SAMN15567684
SAMN15567617
SAMN15567616
SAMN15567615
SAMN15567614
SAMN15567613
SAMN15567612
SAMN15567663
SAMN15567662
SAMN15567661
SAMN15567660
SAMN15567659
SAMN15567658
SAMN15567657
SAMN15567656
SAMN15567655
SAMN15567654
SAMN15567653
SAMN15567652
SAMN15567651
SAMN15567650
SAMN15567649
SAMN15567648
SAMN15567647
SAMN15567646
SAMN15567645
SAMN15567644
SAMN15567643
SAMN15567642
SAMN15567632
SAMN15567631
SAMN15567641
SAMN15567640
SAMN15567611
SAMN15567635
SAMN15567634
SAMN15567633
SAMN15567630
SAMN15567629
SAMN15567628
SAMN15567627
SAMN15567626
SAMN15567625
SAMN15567624
SAMN15567623
SAMN15567622
SAMN15567621
SAMN15567620
SAMN15567619
SAMN15567618
SAMN16792447
SAMN16792447
SAMN16792447
SAMN16792447
SAMN17204655
SAMN17204654
SAMN17204653
SAMN17204652
SAMN17204651
SAMN17204650
SAMN17204649
SAMN17204648
SAMN17204647
SAMN17204646
SAMN17204645
SAMN17204644
SAMN17204643
SAMN17204642
SAMN17204641
SAMN17204640
SAMN17204639
SAMN17204638
SAMN17204672
SAMN17204671
SAMN17204670
SAMN17204669
SAMN17204668
SAMN17204667
SAMN17204666
SAMN17204665
SAMN17204664
SAMN17204663
SAMN17204662
SAMN17204725
SAMN17204724
SAMN17204723
SAMN17204722
SAMN17204721
SAMN17204720
SAMN17204719
SAMN17204718
SAMN17204717
SAMN17204716
SAMN17204715
SAMN17204714
SAMN17204713
SAMN17204712
SAMN17204711
SAMN17204710
SAMN17204709
SAMN17204744
SAMN17204743
SAMN17204742
SAMN17204741
SAMN17204740
SAMN17204739
SAMN17204738
SAMN17204737
SAMN17204736
SAMN17204735
SAMN17204734
SAMN17204733
SAMN17204732
SAMN17204682
SAMN17204681
SAMN17204680
SAMN17204679
SAMN17204678
SAMN17204677
SAMN17204676
SAMN17204675
SAMN17204674
SAMN17204673
SAMN17204708
SAMN17204707
SAMN17204706
SAMN17204705
SAMN17204704
SAMN17204703
SAMN17204702
SAMN17204701
SAMN17204700
SAMN17204699
SAMN17204698
SAMN17204697
SAMN17204696
SAMN17204695
SAMN17204694
SAMN17204693
SAMN17204691
SAMN17204690
SAMN17204726
SAMN17204661
SAMN17204660
SAMN17204692
SAMN17204659
SAMN17204658
SAMN17204657
SAMN17204656
SAMN17204689
SAMN17204688
SAMN17204687
SAMN17204686
SAMN17204685
SAMN17204684
SAMN17204683
SAMN17204731
SAMN17204730
SAMN17204729
SAMN17204728
SAMN17204727
SAMN17204765
SAMN17204764
SAMN17204763
SAMN17204762
SAMN17204761
SAMN17204760
SAMN17204759
SAMN17204758
SAMN17204757
SAMN17204756
SAMN17204755
SAMN17204754
SAMN17204753
SAMN17204752
SAMN17204751
SAMN17204750
SAMN17918218
SAMN17918219
SAMN17918220
SAMN17918221
SAMN17918222
SAMN17918180
SAMN17918181
SAMN17918182
SAMN17918183
SAMN17918184
SAMN17918185
SAMN17918186
SAMN17918187
SAMN17918223
SAMN17918188
SAMN17918189
SAMN17918190
SAMN17918191
SAMN17918192
SAMN17918193
SAMN17918194
SAMN17918195
SAMN17918196
SAMN17918197
SAMN17918224
SAMN17918198
SAMN17918199
SAMN17918200
SAMN17918201
SAMN17918202
SAMN17918203
SAMN17918204
SAMN17918205
SAMN17918206
SAMN17918207
SAMN17918225
SAMN17918208
SAMN17918209
SAMN17918210
SAMN17918211
SAMN17918212
SAMN17918213
SAMN17918214
SAMN17918215
SAMN17918216
SAMN17918217
SAMN17918226
SAMN17918227
SAMN03859850
SAMN31443291
SAMN31443291
SAMN31443276
SAMN31443291
SAMN31443291
SAMN31443290
SAMN31443290
SAMN31443290
SAMN31443289
SAMN31443289
SAMN31443289
SAMN31443288
SAMN31443280
SAMN31443276
SAMN31443280
SAMN31443287
SAMN31443287
SAMN31443287
SAMN31443286
SAMN31443286
SAMN31443286
SAMN31443285
SAMN31443285
SAMN31443285
SAMN31443276
SAMN31443284
SAMN31443284
SAMN31443284
SAMN31443283
SAMN31443283
SAMN31443283
SAMN31443282
SAMN31443282
SAMN31443282
SAMN31443281
SAMN31443275
SAMN31443281
SAMN31443281
SAMN31443280
SAMN31443292
SAMN31443280
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443291
SAMN31443292
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443278
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443277
SAMN31443291
SAMN31443291
SAMN31443292
SAMN31443280
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443279
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443279
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443291
SAMN31443292
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443277
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443277
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443279
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443292
SAMN31443278
SAMN31443292
SAMN31443292
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443291
SAMN31443278
SAMN31443275
SAMN31443275
SAMN07236910
SAMN07236910
SAMN07236909
SAMN07236909
SAMN07257464
SAMN07257464
SAMN07236911
SAMN07236911
SAMN07257464
SAMN07236905
SAMN07236905
SAMN07236904
SAMN07236904
SAMN07236907
SAMN07236907
SAMN07236906
SAMN07236906
SAMN07236908
SAMN07236908