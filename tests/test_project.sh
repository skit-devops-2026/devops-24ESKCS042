set  -e

echo "Running Blood Bank project tests..."


# tests  1 : Main  HTMK file exists
test -f index.html
echo "PASS: index.html exists"

#test 2: CSS file  exists
test -f css/style.css 
echo "PASS:css/style.css exists"

# test 3: HTNL contain the main document structure
grep -q "<html" index.html
grep -q "<head" index.html
grep -q "<body"  index.html
echo "PASS: HTML document structure  is present "

# Test 4 : Page contain blood bank related content 
grep -qi "blood" index.html
echo "PASS : Blood bank content is present"

#Test 5: HTML contain a page title
grep  -q "<title>" index.html
echo "PASS: Page title is present "
echo
echo "All Blood bank project tests passed!"
