;; Anything you type in here will be executed
;; immediately with the results shown on the
;; right.
;; Anything you type in here will be executed
;; immediately with the results shown on the
;; right.
(in-ns 'sportsball.core)

(import 'java.net.URI)

(use 'clojure.repl)
(use 'opennlp.nlp)
(require '[clojure.java.io :refer [reader]])
(require '[cheshire.core :refer [parse-stream]])
(require '[clojure.string :as str])

(def model-uri (URI. "file:///Users/bjeanes/Downloads/clojure-opennlp-master/models/en-token.bin"))

(def tokenise (make-tokenizer (resource "models/en-token.bin")))
(def pos-tag (make-pos-tagger (resource "models/en-pos-maxent.bin")))


(def interview (parse-stream
                (clojure.java.io/reader
                 (resource "corpus/sports/tennis/australian-open/2013-01-12/andy-murray.json"))
                true))

(def andy-murray-text (str/join " " (map :answer (:interview interview))))

(defn has-real-tag?
  [[token tag _]]

  (re-matches #"^[A-Z].*" tag))

(filter has-real-tag?
        (map #(apply conj %)
             (reverse
              (sort-by second
                       (seq (frequencies (pos-tag (tokenise andy-murray-text))))))))
