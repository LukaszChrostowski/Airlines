-- Łukasz Chrostowski       

-- Zadanie 1.
-- Podaj listę artystów [kol 1 - "wykonawca_name"] wraz z ilością uprawianych przez nich gatunków muzycznych [kol 2 - "liczba_gatunków_muzycznych"],
-- posortowaną malejąco względem gatunków muzycznych oraz rosnąco względem nazw artystów. Dodatkowo w kolumnie [kol 3 - "Ranking"]
-- podaj miejsce w rankingu gęstym w porządku malejącym.

WITH cte_tab2
as
    (WITH cte_table
    as
        (SELECT DISTINCT a.name AS wykonawca_name,
               t.genreid
        FROM artist a
        INNER JOIN album a1
        ON a.artistid = a1.artistid 
        INNER JOIN track t
        ON t.albumid = a1.albumid)
    SELECT DISTINCT wykonawca_name,
           count(genreid) over(PARTITION BY wykonawca_name) "liczba_gatunkow_muzycznych"
    FROM cte_table)
SELECT wykonawca_name,
       liczba_gatunkow_muzycznych,
       DENSE_RANK() over(ORDER BY liczba_gatunkow_muzycznych desc) "Ranking"
FROM cte_tab2
ORDER BY liczba_gatunkow_muzycznych DESC, wykonawca_name;


-- Zadanie 2.
-- Jak się ma średnia sprzedaż w danym miesiącu względem średniej sprzedaży z zeszłego miesiąca?
-- Utwórz zestawienie wykorzystując odpowiednią funkcję okna odczytującą poprzedni wiersz:

WITH cte_table1
AS 
    (WITH cte_table
    AS 
        (SELECT EXTRACT(YEAR FROM invoicedate) AS "rok",
               EXTRACT(MONTH FROM invoicedate) AS "miesiąc",
               total
        FROM invoice)
    SELECT DISTINCT rok,
           miesiąc,
           avg(total) OVER(PARTITION BY rok, miesiąc) "średnia"
    from cte_table
    ORDER BY rok)
SELECT rok,
       miesiąc,
       średnia AS "średnia sprzedaż",
       LAG(średnia) OVER() AS "poprzedni miesiąc"
FROM cte_table1;

-- Zadanie 3.
-- Podaj dziesięciu klientów, którzy wydali najwięcej w tym sklepie.

SELECT DISTINCT c.firstname AS imię,
       c.lastname AS nazwisko,
       sum(i.total) over(PARTITION BY c.firstname, c.lastname) kwota_total
FROM customer c
INNER JOIN invoice i 
ON c.customerid = i.customerid
ORDER BY kwota_total DESC
LIMIT 10;

-- Zadanie 4.
-- Podaj rozkład sumy wydanych pieniędzy z podziałem na kraje klientów w procentach z dokładnością do jednego promila. Wynik posortuj od największego udziału.

SELECT DISTINCT billingcountry AS kraj,
       round(sum(total) OVER(PARTITION BY billingcountry) / sum(total) over() * 100, 1) "%"
FROM invoice
ORDER BY "%" DESC;

-- Zadanie 5.
-- Podaj procentowy (z dokładnością do dwóch miejsc po przecinku) udział rodzajów formatów kupionych plików muzycznych
-- z całego zbioru danych oraz dodatkowo z podziałem na gatunki muzyczne. Jakiego gatunku muzycznego nikt nie kupił? 
-- TODO add outer join to the code (?)

WITH cte_tab
AS
    (SELECT g."name" AS nazwa_gatunek,
           m."name" AS nazwa_format,
           count(*) over(PARTITION BY m."name" ORDER BY m."name") ilosc_utworow_format,
           count(*) OVER() ilosc_wszystkich,
           count(*) over(PARTITION BY m."name", g."name" ORDER BY m."name", g."name") ilosc_utworow_format_gatunek
    FROM genre g 
    JOIN track t 
    ON g.genreid = t.genreid 
    JOIN invoiceline i 
    ON i.trackid = t.trackid 
    JOIN mediatype m 
    ON t.mediatypeid = m.mediatypeid)
SELECT DISTINCT nazwa_gatunek, nazwa_format, ilosc_utworow_format,
       Round(CAST(ilosc_utworow_format AS NUMERIC)/CAST(ilosc_wszystkich AS NUMERIC) * 100, 2) AS "%_format",
       ilosc_utworow_format_gatunek,
       round(CAST(ilosc_utworow_format_gatunek AS NUMERIC)/CAST(ilosc_wszystkich AS NUMERIC) * 100, 2) AS "%_format_gatunek"
FROM cte_tab
ORDER BY ilosc_utworow_format DESC, ilosc_utworow_format_gatunek DESC;

-- Zadanie 6.
-- Podaj średni bit rate w kbps dla formatu pliku MPEG, MPEG4 oraz AAC kupionych utworów na dwóch poziomach szczegółowości
-- z podziałem na formaty plików oraz gatunki muzyczne. Wynik zaprezentuj w postaci zaokrąglonej do 
-- dwóch miejsc po przecinku posortowanej ze względu na MediaTypeId oraz GenreId.

WITH cte_tab
AS
    (SELECT DISTINCT m."name" AS format_pliku,
           avg(t.bytes/ t.milliseconds) over(PARTITION BY m."name") średni_bitrate_format,
           g."name" AS gatunek_muzyczny,
           avg(t.bytes / t.milliseconds) over(PARTITION BY g."name") średni_bitrate_gatunek,
           avg(t.bytes / t.milliseconds) over(PARTITION BY m."name", g."name") średni_bitrate_format_gatunek
    FROM genre g 
    JOIN track t 
    ON g.genreid = t.genreid 
    JOIN invoiceline i 
    ON i.trackid = t.trackid 
    JOIN mediatype m 
    ON t.mediatypeid = m.mediatypeid
    ORDER BY format_pliku, gatunek_muzyczny)
SELECT format_pliku,
       round(średni_bitrate_format, 2) AS średni_bitrate_format,
       gatunek_muzyczny,
       round(średni_bitrate_gatunek, 2) AS średni_bitrate_gatunek,
       round(średni_bitrate_format_gatunek, 2) AS średni_bitrate_format_gatunek
FROM cte_tab;

-- Zadanie 7.
-- Napisz funkcję sprawdzającą, czy dwie listy utworów z tabeli Playlist zawierają te same utwory (ten sam zbiór utworów).
-- Funkcja przyjmuje dwa parametry wejściowe - identyfikator listy pierwszej i drugiej, a jej wartością zwracaną jest wartość logiczna.
-- Pary list, dla których funkcja przede wszystkim powinna zwrócić wartość TRUE: 1 i 8 oraz 3 i 10.
-- Listy 2, 4, 6 oraz 7 są puste - można je więc zignorować lub potraktować jako równe.
-- Następnie wywołaj tę funkcję dla wszystkich par playlist, aby znaleźć te same.

CREATE FUNCTION utwory1(integer, integer)
RETURNS boolean
AS 
$$
    WITH T1
    AS
        (SELECT t."name" AS track_name
        FROM playlist p
        INNER JOIN playlisttrack p2
        ON p.playlistid = p2.playlistid
        INNER JOIN track t
        on p2.trackid = t.trackid
        WHERE p.playlistid = $1),
    T2
    AS 
        (SELECT t."name" AS track_name
        FROM playlist p
        INNER JOIN playlisttrack p2
        ON p.playlistid = p2.playlistid
        INNER JOIN track t
        on p2.trackid = t.trackid
        WHERE p.playlistid = $2)
    SELECT
        CASE
            WHEN (
                SELECT array_agg(track_name ORDER BY track_name)
                FROM T1
            ) = (
                SELECT array_agg(track_name ORDER BY track_name)
                FROM T2
            )
            THEN TRUE
            ELSE FALSE
        END AS sets_equal;
$$
LANGUAGE SQL;

SELECT * FROM utwory1(2, 4);

SELECT DISTINCT p1.playlistid,
                p2.playlistid
FROM playlist p1
JOIN playlist p2
ON p1.playlistid != p2.playlistid
WHERE utwory1(p1.playlistid, p2.playlistid);

-- Zadanie 9.
-- Stwórz ranking przedstawicieli działu obsługi klienta (supportrepid), gdzie kryterium oceny to uzyskany najwyższy niezerowy obrót z danego miesiąca.
-- Kwerenda powinna zwrócić tabelę, w której w każdym miesiącu sprzedaży będzie podane imię i nazwisko pracownika miesiąca.

WITH cte_tab2
AS
    (WITH cte_tab
    as
        (SELECT EXTRACT (YEAR FROM i.invoicedate) AS rok,
               EXTRACT (MONTH FROM i.invoicedate) AS miesiąc,
               c.supportrepid AS sprzedawca_miesiaca_id,
               e.firstname AS sprzedawca_miesiaca_imię,
               e.lastname AS sprzedawca_miesiaca_nazwisko,
               sum(i.total) over(PARTITION BY EXTRACT (YEAR FROM i.invoicedate),
                                              EXTRACT (MONTH FROM i.invoicedate),
                                               c.supportrepid) AS total
        FROM employee e 
        INNER JOIN customer c 
        ON e.employeeid  = c.supportrepid
        INNER JOIN invoice i 
        ON i.customerid = c.customerid
        WHERE total>0)
    SELECT rok,
           miesiąc,
           sprzedawca_miesiaca_id,
           sprzedawca_miesiaca_imię,
           sprzedawca_miesiaca_nazwisko,
           max(total) over(PARTITION BY rok, miesiąc) sprzedaz_sum,
           Rank() over(PARTITION BY rok, miesiąc ORDER by total) ranking
    FROM cte_tab)
SELECT DISTINCT rok,
       miesiąc,
       sprzedawca_miesiaca_id,
       sprzedawca_miesiaca_imię,
       sprzedawca_miesiaca_nazwisko,
       sprzedaz_sum
FROM cte_tab2
WHERE ranking = 1;
