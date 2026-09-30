import Testing
import PrestoCVDomain

// Builders shared by the test files. Each fails the test that calls it when the value is not valid.

func partialDate(_ year: Int, _ month: Int? = nil) throws -> PartialDate { try #require(PartialDate(year: year, month: month)) }
func webLink(_ raw: String) throws -> WebLink { try #require(WebLink(raw)) }
func documentLanguage(_ raw: String) throws -> DocumentLanguage { try #require(DocumentLanguage(raw)) }
