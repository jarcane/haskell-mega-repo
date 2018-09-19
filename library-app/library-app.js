futu.onload(function () {
  console.info("Initialising library js");
  // imports
  var $ = futu.$;
  var $_ = futu.$_;
  var $$ = futu.$$;
  var assert = futu.assert;
  var buttonOnClick = futu.buttonOnClick;

  $$("button[data-futu-id=return-loan]").forEach(function (btn) {
    buttonOnClick(btn, function () {
        // prevent dbl-click
        btn.disabled = true;
        var loanId = btn.dataset.loanId;
        fetch("/return/" + loanId, { method: "POST"})
            .then(function (response) { console.log("Return was successful"); location=location.href; })
            .catch(function (error) { console.log("Couldn't return book") });
    });
  });

  $$("button[data-futu-id=loan-item]").forEach(function (btn) {
    buttonOnClick(btn, function () {
        // prevent dbl-click
        btn.disabled = true;
        var bookid = btn.dataset.itemId;
        var office = btn.dataset.library;
        var payload = { "book": parseInt(bookid), "library": office };
        futu.fetchJSON("/book/borrow/", payload)
            .then(function (response) { console.log("Borrow was successful"); location=location.href; })
            .catch(function (error) { console.log("Couldn't borrow book") });
    });
  });

    $("form[data-futu-id=add-new-book]").onsubmit = function () {
        $$('span.alert').forEach(function (s) {
            s.remove();
        });
        var isbn = $("form[data-futu-id=add-new-book] input[name='isbn']").value;
        if (/[^0-9\-]+/g.test(isbn)) {
            var isbnAlert = document.createElement("span");
            isbnAlert.className = 'alert label';
            isbnAlert.innerText = 'No letters allowed in isbn';
            futu.$("form[data-futu-id=add-new-book] input[name='isbn']").after(isbnAlert);
            return false;
        }
        return true;
    };

    $$("select[data-futu-id=add-new-item-select").forEach(function (sel) {
        sel.onchange = function () {
            $$("form").forEach(function (s) { s.style.display = "none" });
            if (this.value === "Book") {
                $$("form[data-futu-id=add-new-book]").forEach(function (s) { s.style.display = "block" });
            } else if (this.value === "Boardgame") {
                $$("form[data-futu-id=add-new-boardgame]").forEach(function (s) { s.style.display = "block" });
            }
        };
    });

    $$("button[data-futu-id=find-by-isbn]").forEach(function (btn) {
        buttonOnClick(btn, function () {
            var isbn = $("input#isbn").value;
            if(isbn) {
                $("form[data-futu-id=add-new-book] input[name='bookinformationid']").value = '';
                futu.fetchJSON("/book/isbn/" + isbn)
                    .then(function (response) {
                        //Fill form with the isbn values
                        if(response.dataSource.source === 'Database') {
                            $("form[data-futu-id=add-new-book] input[name='bookinformationid']").value = response.dataSource.bookinformationid;
                            $("form[data-futu-id=add-new-book] input[name='title']").value = response.title;
                            $("form[data-futu-id=add-new-book] input[name='author']").value = response.author;
                            $("form[data-futu-id=add-new-book] input[name='publisher']").value = response.publisher;
                            $("form[data-futu-id=add-new-book] input[name='published']").value = response.published;
                            $("form[data-futu-id=add-new-book] input[name='amazon-link']").value = response.amazonLink;
                            var currentBooks = '<ul>';
                            for (var lib in response.books) {
                                currentBooks = currentBooks + '<li>' + lib + ' ' + response.books[lib] + '</li>';
                            }
                            currentBooks = currentBooks + '</ul>';
                            $("div#info-box").innerHTML =
                                '<span class="label warning">Books with this ISBN exists already in these libraries:'+currentBooks+'Add new copies by selecting a library and quantity.</span>';
                            $("img#cover-image").src = "/book/cover/" + response.dataSource.coverhash;
                            $("img#cover-image").style.display = "block";
                        } else if(response.dataSource.source === 'Amazon') {
                            $("form[data-futu-id=add-new-book] input[name='title']").value = response.title;
                            $("form[data-futu-id=add-new-book] input[name='author']").value = response.author;
                            $("form[data-futu-id=add-new-book] input[name='publisher']").value = response.publisher;
                            $("form[data-futu-id=add-new-book] input[name='published']").value = response.published;
                            $("form[data-futu-id=add-new-book] input[name='amazon-link']").value = response.amazonLink;
                            $("div#info-box").innerHTML = '<span class="label warning">Book information found from Amazon</span>';
                            $("form[data-futu-id=add-new-book] input[name='cover-url']").value = response.dataSource.coverurl;
                            $("img#cover-image").src = response.dataSource.coverurl;
                            $("img#cover-image").style.display = "block";
                        }})
                    .catch(function (error) {
                        $("div#info-box").innerHTML = '<span class="info">No books found in database with this ISBN</span>';
                    });
            }
        });
    });
});
