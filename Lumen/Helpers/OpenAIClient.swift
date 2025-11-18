import Foundation

class OpenAIClient {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyzeFeedback(_ feedback: String, completion: @escaping (String?, String?) -> Void) {
        let prompt = "Categorize the following feedback as 'Suggestion', 'Issue', or 'Other' and provide a one-sentence summary.\nFeedback: \(feedback)\nFormat: Category: <category>\nSummary: <summary>"
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 100
        ]
        guard let url = URL(string: endpoint),
              let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(nil, nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(nil, nil)
                return
            }
            // Parse category and summary from response
            let lines = content.components(separatedBy: "\n")
            var category: String? = nil
            var summary: String? = nil
            for line in lines {
                if line.lowercased().hasPrefix("category:") {
                    category = line.replacingOccurrences(of: "Category:", with: "").trimmingCharacters(in: .whitespaces)
                } else if line.lowercased().hasPrefix("summary:") {
                    summary = line.replacingOccurrences(of: "Summary:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }
            completion(category, summary)
        }.resume()
    }
}
