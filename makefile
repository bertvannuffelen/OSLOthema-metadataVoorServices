# List of input files (example files)
#INPUTS=6.output.jsonld 7.output.jsonld 8.output.jsonld
INPUTS=metadata_dcat.jsonld dcatapvl.jsonld
# INPUTS=release/metadata_dcat.jsonld release/dcatapvl.jsonld
OUTPUTCSV=$(patsubst %.jsonld,%.csv,${INPUTS})

all: final_with_description.csv final_with_testcount.csv

%.csv: %.jsonld
	# Entract the ruleid and the id into a file which sorted on the first key (ruleid)
	jq '.shapes[]."sh:property"[] | [."vl:rule",."@id"] | join(";")' $< | sed 's/\"//g' | awk -F ';' '{if ($$1=="") {print sprintf("%s-%03d","$<",NR)";"$$2;} else {print $$0;}}' | sort -d -t ";" -k 1 > $@
	# Add the filename as a header for the 2nd column
	sed -i '1s?.*?vl:rule;$<?' $@
	sed -i "s/\r//g" $@

	# join the files as needed
final.csv: ${OUTPUTCSV}
	#Extract all the ids know from the csv files and sort as seed file
	cat ${OUTPUTCSV} | awk -F ";" '$$1!="vl:rule"{print $$1"";}' | sort -d -t ";" -k 1 | uniq > final.csv
	sed -i '1s/.*/vl:rule/' final.csv
	cp final.csv final_seed.csv
	for f in ${OUTPUTCSV}; do join --header -t ";" -j 1 -a 1 -e "_" -o auto final.csv $${f} > tmp.csv; mv tmp.csv final.csv; done
	sed -i "s/\r//g" final.csv

	# Merge in any description/extra information which is needed.
final_with_description.csv: final.csv sdescription.csv
	join -e "_" -o auto --header -t ";" -j 1 -a 1 final.csv sdescription.csv > $@

sdescription.csv: description.csv
	sort -d -t ";" -k 1 description.csv > $@
	sed -i '1s/.*/;description/' $@

# Process the rulefiles
TESTDATAFILES=${wildcard testdata/*.nt}
TESTDATARES=$(patsubst %.nt,%.jsonld,${TESTDATAFILES})
TESTDATARESCSV=$(patsubst %.nt,%.csv,${TESTDATAFILES})

final_with_testcount.csv: uniq.csv final_with_description.csv
	(head -n 2 final_with_description.csv && tail -n +3 final_with_description.csv | sort -d -t ";" -k 3 ) > sdescription.csv
	sed -i '1s/.*/;;test-count/' uniq.csv
	join --header -t ";" -1 3 -2 1 -a 1 -o 1.1,2.3,1.2,1.3,1.4 -e "_" sdescription.csv uniq.csv > final_with_testcount.csv

.PRECIOUS: testdata/%.jsonld
testdata/%.jsonld: testdata/%.nt
	curl -H "Content-type:application/json" \
	     -H "Accept: application/json" \
	     -d '{"contentToValidate":"https://github.com/Informatievlaanderen/OSLOthema-metadataVoorServices/raw/validation/$<","validationType":"dcat_ap_vl", "reportSyntax":"application/ld+json"}' \
	     https://data.dev-vlaanderen.be/shacl-validator-backend/shacl/applicatieprofielen/api/validate > $@

.PRECIOUS: testdata/%.csv
testdata/%.csv: testdata/%.jsonld
	jq '."@graph"[] | [."sourceShape",."@id"] | join(";")' $< | sed 's/\"//g' | sort -t ";" -k 1 > $@
	sed -i "s/\r//g" $@

uniq.csv: ${TESTDATARESCSV}
	cat ${TESTDATARESCSV} | awk -F ';' '{print $1;}' | sort | uniq -c | awk '{print $$2";"$$1;}' > uniq.csv

clean:
	rm -rf ${OUTPUTCSV} final.csv tmp.csv final_with_description.csv ${TESTDATARESCSV} uniq.csv final_with_testcount.csv ${TESTDATARES} sdescription.csv sfinal.csv
