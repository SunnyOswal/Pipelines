import axios, { AxiosResponse, AxiosError } from 'axios';

class AuthHelper {
  private tokenForCloudFront: string = undefined;

  public async tokenForCloudFrontEndpoints(): Promise<string> {
    if (this.tokenForCloudFront !== undefined) {
      return this.tokenForCloudFront;
    }

    const authEndpointForCloudFront = process.env.BP_AUTH0_URL;
    const authClientId = process.env.BP_FBI_CLIENT_ID;
    const authSecretId = process.env.BP_FBI_CLIENT_SECRET;
    const authAudience = process.env.BP_FBI_AUDIENCE;
    const authGrantType = 'client_credentials';
    const authbody = {
      client_id: authClientId,
      client_secret: authSecretId,
      audience: authAudience,
      grant_type: authGrantType,
    };
    const opt = {
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    };
    const res: AxiosResponse = await axios.post(authEndpointForCloudFront, authbody, opt).catch((error: AxiosError) => {
      console.log('Failed to call authHelper with authbody: ', JSON.stringify(authbody));
      console.log('Failed to call authHelper with opt: ', JSON.stringify(opt));
      console.log('Failed to call authHelper with authEndpointForCloudFront: ', authEndpointForCloudFront);
      console.log('Failed to call authHelper: ', error.message);
      throw Error(error.message);
    });
    this.tokenForCloudFront = res.data.access_token;
    return this.tokenForCloudFront;
  }
}

const authHelper = new AuthHelper();
export default authHelper;
