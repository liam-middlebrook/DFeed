/*  Copyright (C) 2011, 2012  Vladimir Panteleev <vladimir@thecybershadow.net>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

module recaptcha;

import std.string;

import ae.net.http.client;

import captcha;

class Recaptcha : Captcha
{
	override string getChallengeHtml(CaptchaErrorData errorData)
	{
		string error = errorData ? (cast(RecaptchaErrorData)errorData).code : null;

		auto publicKey = getOptions().publicKey;
		return
			`<script type="text/javascript" src="http://www.google.com/recaptcha/api/challenge?k=` ~ publicKey ~ (error ? `&error=` ~ error : ``) ~ `">`
			`</script>`
			`<noscript>`
				`<iframe src="http://www.google.com/recaptcha/api/noscript?k=` ~ publicKey ~ (error ? `&error=` ~ error : ``) ~ `"`
					` height="300" width="500" frameborder="0"></iframe><br>`
				`<textarea name="recaptcha_challenge_field" rows="3" cols="40">`
				`</textarea>`
				`<input type="hidden" name="recaptcha_response_field" value="manual_challenge">`
			`</noscript>`;
	}

	override bool isPresent(string[string] fields)
	{
		return "recaptcha_challenge_field" in fields && "recaptcha_response_field" in fields;
	}

	override void verify(string[string] fields, string ip, void delegate(bool success, string errorMessage, CaptchaErrorData errorData) handler)
	{
		assert(isPresent(fields));

		httpPost("http://www.google.com/recaptcha/api/verify", [
			"privatekey" : getOptions().privateKey,
			"remoteip" : ip,
			"challenge" : fields["recaptcha_challenge_field"],
			"response" : fields["recaptcha_response_field"],
		], (string result) {
			auto lines = result.splitLines();
			if (lines[0] == "true")
				handler(true, null, null);
			else
				handler(false, lines.length>1 ? "reCAPTCHA error" : result, new RecaptchaErrorData(lines[1]));
		}, (string error) {
			handler(false, error, null);
		});
	}

private:
	struct RecaptchaOptions { string publicKey, privateKey; }
	static RecaptchaOptions getOptions()
	{
		import std.file, std.string;
		auto lines = splitLines(readText("data/recaptcha.txt"));
		return RecaptchaOptions(lines[0], lines[1]);
	}
}

class RecaptchaErrorData : CaptchaErrorData
{
	string code;
	this(string code) { this.code = code; }
}

static this()
{
	theCaptcha = new Recaptcha();
}
